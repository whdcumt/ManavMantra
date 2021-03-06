classdef AppMode
    enumeration
        NoImageLoaded               
        ImageLoaded                 
        NoMasks                      
        MasksExist                        
        Drawing 
        ActiveContoursTabOpened
        ActiveContoursRunning 
        ActiveContoursIterationsDone
        ActiveContoursNoMask
        ActiveContoursDone
        FloodFillTabOpened
        FloodFillSelection          
        DrawingDone                  
        FloodFillDone          
        HistoryIsEmpty
        HistoryIsNotEmpty
        ThresholdImage
        ThresholdDone
        MorphTabOpened
        MorphImage
        MorphologyDone
        OpacityChanged
        ShowBinary
        UnshowBinary
        GraphCutOpened
        GraphCutDone
        FindCirclesOpened
        FindCirclesDone
        ToggleTexture
        GrabCutOpened
        GrabCutDone
    end
end