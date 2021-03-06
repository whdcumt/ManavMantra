classdef (Hidden) IndexedAviFilePlugin < audiovideo.internal.writer.plugin.AviFilePlugin
    %IndexedAviFilePlugin Extension of the AviFilePlugin class to write Indexed
    %AVI Files
    
    % Copyright 2012-2013 The MathWorks, Inc.
    
    methods
        function obj = IndexedAviFilePlugin(fileName)
            %IndexedAviFilePlugin Construct a IndexedAviFilePlugin object.
            %
            %   OBJ = IndexedAviFilePlugin(FILENAME) constructs a
            %   IndexedAviFilePlugin object pointing to the file specified
            %   by FILENAME.  The file is not created until
            %   IndexedAviFilePlugin.open() is called. 
            %
            %   See also IndexedAviFilePlugin/open, IndexedAviFilePlugin/close.
            
            obj = obj@audiovideo.internal.writer.plugin.AviFilePlugin(fileName);
            
            obj.ColorFormat = 'Indexed';
            obj.ColorChannels = 1;
            obj.BitsPerPixel = 8;
            
            % Handle the zero argument constructor.  This is needed, for
            % example, when constructing empty profile objects.
            if isempty(fileName)
                obj.Channel = [];
                return;
            end
            
            obj.FileName = fileName;
        end
        
        function setColormap(obj, cmap)
            % Create an asyncio Channel options structure
            % with format specific properties to be used during
            % execute@asyncio.Channel
            options.Colormap = audiovideo.internal.writer.convertColormapToUint8(cmap);
            obj.execute('setColormap', options);
        end
        
        function open(obj, options)
            if isfield(options, 'Colormap')
                options.Colormap = audiovideo.internal.writer.convertColormapToUint8(options.Colormap);
            end
            open@audiovideo.internal.writer.plugin.AviFilePlugin(obj, options)
        end
        
        function [pluginName, mlConverterName, slConverterName, options] = ...
                                                getChannelInitOptions(obj)
            [pluginName, mlConverterName, slConverterName, options] = ...
                        getChannelInitOptions@audiovideo.internal.writer.plugin.AviFilePlugin(obj);
            options.FileFormat = obj.ColorFormat;
        end
        
        function [filterName, options] = getFilterInitOptions(obj)
            filterName = 'videotransformfilter';
            options.InputFrameType = 'RawPlanarColumn';
            if ~isempty(obj.Channel)
                options.OutputFrameType = obj.Channel.ExpectedFrameType;
            else
                options.OutputFrameType = '';
            end
        end         
    end
    
    methods(Access=protected)
        
        function [mlErrorID, msgHoles] = deviceErrorToErrorID(obj, deviceErr, deviceMsg)
            %DEVICEERRORTOERRORID conversion from Device Error ID to MATLAB
            %Error ID
            %   Convert the Error ID generated by the Device Plugin to a
            %   MATLAB Error ID. Each plugin has knowledge about the
            %   specific errors that are thrown by the corresponding Device
            %   Plugin
            msgHoles = {};
            mlPrefix =  audiovideo.internal.writer.plugin.IPlugin.ErrorPrefix;
            
            switch(deviceErr)
                case 'aviplugin:couldNotSetColormap'
                    mlErrorID = sprintf('%s:%s', mlPrefix, 'couldNotSetColormap');
                    msgHoles = {deviceMsg};
                case 'aviPlugin:colormapRequiredForIndexed'
                    mlErrorID = sprintf('%s:%s', mlPrefix, 'colormapRequiredForIndexed');
                case 'aviPlugin:invalidColormap'
                    mlErrorID = sprintf('%s:%s', mlPrefix, 'invalidColormap');
                case 'aviplugin:cannotSetColormapAfterStartingWrite'
                    mlErrorID = sprintf('%s:%s', mlPrefix, 'colormapVarying');
                otherwise
                    [mlErrorID, msgHoles] = deviceErrorToErrorID@audiovideo.internal.writer.plugin.AviFilePlugin(obj, deviceErr);
            end
        end
        
    end
    
    methods(Access=private)
        function execute(obj, command, options)
            %EXECUTE Executes a command on the channel.
            %   IndexedAviFilePlugin objects must be open prior to calling
            %   execute.
            
            assert(~isempty(obj.Channel), 'Channel must be set before writing to the plugin');
            assert(obj.Channel.isOpen(), 'Channel must be open before writing data.');
            
            try
                switch command
                    case 'setColormap'
                        obj.Channel.execute(command, options);
                    otherwise
                        assert(false, 'Invalid command to execute on the channel');
                end
            catch ME
                throwAsCaller(ME);
            end 
        end
    end
end