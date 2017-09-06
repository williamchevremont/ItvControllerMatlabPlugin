


classdef ITV < handle
    % Class for the control of ITV-controller
    % 2017-09-05 William Chèvremont
    properties (Hidden=true)
        m_com;
        m_N;
    end    
    methods
        % C-tor
        function obj = ITV(com, speed)
            % Constructor.
            % Call options: 
            %   ITV(com)
            %       com     : a serial object, open or not.
            %   ITV(com,speed)
            %       com     : the serial identifier, such as COM1 (win) or
            %                 /dev/ttyS0 (linux)
            %       speed   : communication speed
            if nargin == 1 && isa(com,'serial')
                s = com;
            else
                
                instrs = instrfind('Port',com);
                
                if ~isempty(instrs)
                    fclose(instrs);
                end
                
                s = serial(com,'BaudRate',speed);
            end
            
            if strcmp(s.Status,'closed')
                disp('opening the device');
                fopen(s);
            end
            
            obj.m_com = s;
            obj.m_N = -1;
        end
        
        % D-tor
        function delete(obj)
            % Destructor
            % Close the serial object
            fclose(obj.m_com);
        end
        
        % disp
        function disp(obj)
            % Disp
            % Display usefull parameters
            
            disp(['Serial communication:']);
            disp(' ');
            disp(['Serial port: ',obj.m_com.Port]);
            disp(['Communication speed: ',num2str(obj.m_com.BaudRate)]);
            disp(['Communication is actually: ',obj.m_com.Status]);
            disp(' ');
            disp(['Status:']);
            disp(' ');
            if obj.m_N >= 0
                disp(['Controller initialized']);
                disp(['Number of devices: ',num2str(obj.m_N)]);
            else
                disp(['Device unitialized']);
            end
        end
        
        function N = getNumberOfDevices(obj)
            % Function that return the number of device associated to the
            % controller.
            if(obj.m_N < 0)
                error('Object is unitialized. Call init() before any other methods.');
            end
            N = obj.m_N;
        end
        
        % init
        function init(obj)
            % Function that initialize the object according to the
            % controller parameters.
            
            obj.cleanInputBuffer();
            fprintf(obj.m_com,'--');
            fprintf(obj.m_com,'STATUS_FMTT--');
            
            r = '';
            
            while isempty(regexp(r,'^200 : \(CMD\) STATUS_FMTT','match'))
                r = fscanf(obj.m_com);
            end
            
            r = fscanf(obj.m_com);
            
            tokN = regexp(r(1:end-2),'^202 : ([0-9]+) ','tokens');
            %tokVal = regexp(r(1:end-2),': (OFF|ON) : ([0-9]+) : ([0-9]+)','tokens');
            
            obj.m_N = str2double(tokN{1,1}{1,1});
            
            if(obj.m_N > 0)
                disp(['Controller inited and has ',num2str(obj.m_N),' device(s)']);
            else
                warning('Controller has no device configured');
            end
        end
        
        % Get devices current values
        function ret = getState(obj)
            % Function that return a table with the state of each device.
            
            if(obj.m_N < 0)
                error('Object is unitialized. Call init() before any other methods.');
            end
            
            obj.cleanInputBuffer();
            fprintf(obj.m_com,'STATUS_FMTT--');
            
            r = '';
            
            while isempty(regexp(r,'^200 : \(CMD\) STATUS_FMTT','match'))
                r = fscanf(obj.m_com);
            end
            
            r = fscanf(obj.m_com);
            
            %tokN = regexp(r(1:end-2),'^202 : ([0-9]+) ','tokens');
            tokVal = regexp(r(1:end-2),': (OFF|ON) : ([0-9]+) : ([0-9]+)','tokens');
            
            status = cell(obj.m_N,1);
            sp = zeros(obj.m_N,1);
            cv = zeros(obj.m_N,1);
            rn = cell(1,obj.m_N,1);
            
            for i=1:length(tokVal)
                status{i} = tokVal{1,i}{1,1};
                sp(i) = str2double(tokVal{1,i}{1,2});
                cv(i) = str2double(tokVal{1,i}{1,3});
                rn{i} = num2str(i);
            end
            
            ret = table(status,sp,cv,'RowNames',rn,'VariableNames',{'Status','SetPoint','Value'});
            
        end
        
        % Turn on or off some devides
        function ret = setOnOff(obj,onoff,id)
            % Function that turn on and off the devices.
            % Call options:
            %   setOnOff(onoff)
            %       onoff   : a cell array containing 'ON' or 'OFF' for each
            %                 device
            %   setOnOff(onoff,id)
            %       onoff   : char array containing 'ON' or 'OFF'
            %       id      : device id to turn on or off
            obj.cleanInputBuffer();
            
            ret = 1;
            
            if nargin == 2
                
                for i=1:obj.m_N
                    if isempty(regexp(onoff{i},'^(ON|OFF)$','match'))
                        error('onoff must contain only ON or OFF');
                    end
                end
                
                if length(val) ~= obj.m_N
                    error('onoff must have the same number of elements than controllers or a single value associated with id as third argument');
                end
                
                if ~isa(onoff,'cell')
                    error('onoff must be a cell array with ON or OFF value for each device, or single value associated with id');
                end
                
                for i=1:obj.m_N
                    
                    fprintf(obj.m_com,sprintf('%s %i--',onoff{i},i));
                    cmdr = fscanf(obj.m_com);
                    
                    if isempty(regexp(cmdr,'^2','match'))
                        warning(['Error from controller: ',cmdr(1:end-2)]);
                        ret=0;
                    else
                        retcmd = fscanf(obj.m_com);

                        if isempty(regexp(retcmd,'^2','match'))
                            warning(['Error from controller: ',retcmd(1:end-2)]);
                            ret=0;
                        end
                    end
                end
                return;
            end
            
            if nargin == 3
                if id <= 0 || id > obj.m_N
                    error('id must be a valid device identifier');
                end
                
                if ~isa(onoff,'char')
                    error('onoff must be a char array when associated with id');
                end
                
                if isempty(regexp(onoff,'^(ON|OFF)$','match'))
                    error('onoff must contain only ON or OFF');
                end
                
                fprintf(obj.m_com,sprintf('%s %i--',onoff,id));
                cmdr = fscanf(obj.m_com);
                    
                if isempty(regexp(cmdr,'^2','match'))
                    warning(['Error from controller: ',cmdr(1:end-2)]);
                    ret=0;
                else
                    retcmd = fscanf(obj.m_com);

                    if isempty(regexp(retcmd,'^2','match'))
                        warning(['Error from controller: ',retcmd(1:end-2)]);
                        ret=0;
                    end
                end
            end
        end
        
        % Set value to some devices
        function ret = setVal(obj,val, id)
            % Function that set values for each device.
            % Call options:
            %   setVal(val)
            %       val    : a vector with each setpoint (between 0 and
            %                100)
            %   setOnOff(onoff,id)
            %       val    : new setpoint for device id
            %       id     : device id
            obj.cleanInputBuffer();
            ret=1;
            if nargin == 2
                if length(val) ~= obj.m_N
                    error('val must have the same number of elements than controllers or a single value associated with id as third argument');
                end
                
                for i=1:obj.m_N
                    fprintf(obj.m_com,sprintf('SET %i %i--',i,val(i)));
                    cmdr = fscanf(obj.m_com);
                    
                    if isempty(regexp(cmdr,'^2','match'))
                        warning(['Error from controller: ',cmdr(1:end-2)]);
                        ret=0;
                    else
                        retcmd = fscanf(obj.m_com);

                        if isempty(regexp(retcmd,'^2','match'))
                            warning(['Error from controller: ',retcmd(1:end-2)]);
                            ret=0;
                        end
                    end
                end
                return;
            end
            
            if nargin == 3
                if id <= 0 || id > obj.m_N
                    error('id must be a valid device identifier');
                end

                if length(val) > 1
                    error('when id specified, val must be a scalar. Otherwise, val must contain new setpoint for each device.');
                end
                
                fprintf(obj.m_com,sprintf('SET %i %i--',id,val));
                cmdr = fscanf(obj.m_com);
                    
                if isempty(regexp(cmdr,'^2','match'))
                    warning(['Error from controller: ',cmdr(1:end-2)]);
                    ret=0;
                else
                    retcmd = fscanf(obj.m_com);

                    if isempty(regexp(retcmd,'^2','match'))
                        warning(['Error from controller: ',retcmd(1:end-2)]);
                        ret=0;
                    end
                end
            end
        end 
    end
    methods(Access=protected)
        % Clean input buffer
        function cleanInputBuffer(obj)
            while(obj.m_com.BytesAvailable > 0)
                fscanf(obj.m_com);
            end
        end
    end    
end
