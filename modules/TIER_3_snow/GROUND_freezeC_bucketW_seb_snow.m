%========================================================================
% CryoGrid GROUND class GROUND_freezeC_bucketW_seb_snow
% heat conduction, bucket water scheme, freeze curve based on
% freezing=drying assumption, surface energy balance
% coupling to SNOW classes
% S. Westermann, October 2020
%========================================================================

classdef GROUND_freezeC_bucketW_seb_snow < GROUND_freezeC_bucketW_seb
    properties
        CHILD
        IA_CHILD
    end
    
    
    methods
        
        %----mandatory functions---------------
        %----initialization--------------------
        
        function ground = GROUND_freezeC_bucketW_seb_snow(index, pprovider, cprovider, forcing)
            ground@GROUND_freezeC_bucketW_seb(index, pprovider, cprovider, forcing);
        end
        
        function ground = provide_PARA(ground)
            ground = provide_PARA@GROUND_freezeC_bucketW_seb(ground);
        end
        
        function ground = provide_CONST(ground)
            ground = provide_CONST@GROUND_freezeC_bucketW_seb(ground);
        end
        
        function ground = provide_STATVAR(ground)
            ground = provide_STATVAR@GROUND_freezeC_bucketW_seb(ground);
        end
        
        function ground = finalize_init(ground, forcing)
            ground = finalize_init@GROUND_freezeC_bucketW_seb(ground, forcing);
            ground.CHILD = 0; % no snow in the beginning
            ground.IA_CHILD = 0;
        end
        
        
        %---time integration------
        
        function ground = get_boundary_condition_u(ground, forcing)
            
            if ground.CHILD == 0  %SNOW CHILD does not exist
                ground = get_boundary_condition_u@GROUND_freezeC_bucketW_seb(ground, forcing); %call the native function for the ground class
                
                if forcing.TEMP.snowfall > 0  %create SNOW CHILD
                    CURRENT = ground.PREVIOUS;  %go to Top() and get the stored SNOW class
                    while ~strcmp(class(CURRENT), 'Top')
                        CURRENT = CURRENT.PREVIOUS;
                    end
                    ground.CHILD = copy(CURRENT.STORE.SNOW);
                    ground.CHILD.PARENT = ground;
                    ground.CHILD.NEXT = ground;
                    ground.IA_CHILD = get_IA_class(class(ground.CHILD), class(ground));
                    ground.IA_CHILD.PREVIOUS = ground.CHILD;
                    ground.IA_CHILD.NEXT = ground; %SNOW CHILD created
                    
                    ground.CHILD = get_boundary_condition_u_create_CHILD(ground.CHILD, forcing);  %initialize with fresh snowfall
                end
            else %SNOW CHILD exists
                total_area = ground.STATVAR.area; %store the totals of the GROUND class
                total_waterIce = ground.STATVAR.waterIce;
                total_water = ground.STATVAR.water;
                total_ice = ground.STATVAR.ice;
                total_mineral = ground.STATVAR.mineral;
                total_organic = ground.STATVAR.organic;
                
                %split up area in snow-covered (CHILD) and snow-free part (PARENT) 
                ground.STATVAR.area = ground.STATVAR.area - ground.CHILD.STATVAR.area(1,1); %replace by snow-free area
                reduction = ground.STATVAR.area(1) ./ total_area(1);
                ground.STATVAR.waterIce = ground.STATVAR.waterIce .* reduction;
                ground.STATVAR.water = ground.STATVAR.water .* reduction;
                ground.STATVAR.ice = ground.STATVAR.ice .* reduction;
                ground.STATVAR.mineral = ground.STATVAR.mineral .* reduction;
                ground.STATVAR.organic = ground.STATVAR.organic .* reduction;
                
                %-------------
                
                ground.CHILD.STATVAR.Lstar = ground.STATVAR.Lstar;
                
                ground.CHILD = get_boundary_condition_u_CHILD(ground.CHILD, forcing);
                ground = get_boundary_condition_u@GROUND_freezeC_bucketW_seb(ground, forcing);
                
                get_IA_CHILD_boundary_condition_u(ground.IA_CHILD);
                %call designated mandatory function for CHILD-PARENT interactions in
                %the IA class governing IA between SNOW and GROUND
                
                ground.STATVAR.Lout = (ground.STATVAR.area(1,1) .* ground.STATVAR.Lout + ground.CHILD.STATVAR.area .* ground.CHILD.STATVAR.Lout) ./ total_area(1,1); %mix the surface heat fluxes from snow and ground
                ground.STATVAR.Sout = (ground.STATVAR.area(1,1) .* ground.STATVAR.Sout + ground.CHILD.STATVAR.area .* ground.CHILD.STATVAR.Sout) ./ total_area(1,1);
                ground.STATVAR.Qh = (ground.STATVAR.area(1,1) .* ground.STATVAR.Qh + ground.CHILD.STATVAR.area .* ground.CHILD.STATVAR.Qh) ./ total_area(1,1);
                ground.STATVAR.Qe = (ground.STATVAR.area(1,1) .* ground.STATVAR.Qe + ground.CHILD.STATVAR.area .* ground.CHILD.STATVAR.Qe) ./ total_area(1,1);
                
                %reassign the true totals of ground
                ground.STATVAR.area = total_area; 
                ground.STATVAR.waterIce = total_waterIce;
                ground.STATVAR.water = total_water;
                ground.STATVAR.ice = total_ice;
                ground.STATVAR.mineral = total_mineral;
                ground.STATVAR.organic = total_organic;
                
            end
        end
        
        function [ground, S_up] = penetrate_SW(ground, S_down)  %mandatory function when used with class that features SW penetration
            [ground, S_up] = penetrate_SW@GROUND_freezeC_bucketW_seb(ground, S_down);
        end
        
        function ground = get_boundary_condition_l(ground, forcing)
            ground = get_boundary_condition_l@GROUND_freezeC_bucketW_seb(ground, forcing);
            
        end
        
        function ground = get_derivatives_prognostic(ground)
            if ground.CHILD == 0
                ground = get_derivatives_prognostic@GROUND_freezeC_bucketW_seb(ground); %call normal function
            else
                ground.CHILD = get_derivatives_prognostic_CHILD(ground.CHILD);
                ground = get_derivatives_prognostic@GROUND_freezeC_bucketW_seb(ground);
            end
        end
        
        function timestep = get_timestep(ground)
            if ground.CHILD == 0
                timestep = get_timestep@GROUND_freezeC_bucketW_seb(ground);
            else
                timestep_snow = get_timestep_CHILD(ground.CHILD);
                timestep_ground =  get_timestep@GROUND_freezeC_bucketW_seb(ground);
                timestep = timestep_ground + double(timestep_snow > 0 && timestep_snow < timestep_ground) .* (timestep_snow - timestep_ground);
            end
        end
        
        function ground = advance_prognostic(ground, timestep)
            if ground.CHILD == 0
                ground =  advance_prognostic@GROUND_freezeC_bucketW_seb(ground, timestep);
            else
                ground.CHILD = advance_prognostic_CHILD(ground.CHILD, timestep);
                ground =  advance_prognostic@GROUND_freezeC_bucketW_seb(ground, timestep);
            end
        end
        
        function ground = compute_diagnostic_first_cell(ground, forcing);
            ground = L_star(ground, forcing);
        end
        
        function ground = compute_diagnostic(ground, forcing)
            if ground.CHILD == 0
                ground = compute_diagnostic@GROUND_freezeC_bucketW_seb(ground, forcing);
            else
                ground = compute_diagnostic@GROUND_freezeC_bucketW_seb(ground, forcing);
                ground.CHILD = compute_diagnostic_CHILD(ground.CHILD, forcing);
                
            end
        end
        
        function ground = check_trigger(ground, forcing)
            if ground.CHILD ~= 0
                %delete CHILD
                if ground.CHILD.STATVAR.area ./ ground.STATVAR.area(1,1) < 1e-6 %cutoff to get rid of remaining snow
                    ground.CHILD = 0;
                    ground.IA_CHILD = 0;
                    %make SNOW CHILD full class
                elseif ground.CHILD.STATVAR.area ./ ground.STATVAR.area(1,1) > 1
                    %transforms dimensions and STAVAR
                    snow_volume = ground.CHILD.STATVAR.area .* ground.CHILD.STATVAR.layerThick;
                    ground.CHILD.STATVAR.area = ground.STATVAR.area(1,1);
                    ground.CHILD.STATVAR.layerThick = snow_volume ./ ground.CHILD.STATVAR.area;
                     
                    %make snow a real class
                    ground.CHILD.PARENT = 0;
                    ground.CHILD.PREVIOUS = ground.PREVIOUS;
                    ground.CHILD.NEXT = ground;
                    ground.PREVIOUS.NEXT = ground.CHILD;
                    ground.PREVIOUS = ground.CHILD;
                    ground.CHILD = 0;
                    ground.IA_PREVIOUS = ground.IA_CHILD;
                    ground.PREVIOUS.IA_NEXT = ground.IA_CHILD;
                    ground.IA_CHILD = 0;
                end
            end
        end
        
    end
end