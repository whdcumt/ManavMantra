classdef AddAssumptionEventDecorator < matlab.unittest.internal.TaskDecorator
    
    % Copyright 2016-2017 The MathWorks, Inc.
    
    methods
        function objArray = AddAssumptionEventDecorator(tasks)
            objArray = objArray@matlab.unittest.internal.TaskDecorator(tasks);
        end
    end
    
    methods (Access=protected)
        function diags = getElementAssumptionDiagnostics(task)
            diags = task.getDefaultQualificationDiagnostics;
        end
    end
end

% LocalWords:  TASKDECORATOR diags