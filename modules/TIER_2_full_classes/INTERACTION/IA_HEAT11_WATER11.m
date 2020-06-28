classdef IA_HEAT11_WATER11 < IA_WATER & IA_HEAT 
    
    methods
        
        function get_boundary_condition_m(ia_heat_water)
            get_boundary_condition_HEAT_m(ia_heat_water);
            get_boundary_condition_BUCKET_m(ia_heat_water);
            ia_heat_water.NEXT.TEMP.surface_runoff = 0;
        end
        

    end
end