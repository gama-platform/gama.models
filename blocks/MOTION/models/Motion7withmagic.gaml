/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	geometry free_space <- copy(shape);
	graph network;
	
	init {
		
		list<geometry> geoms <- to_rectangles(world.shape,4,5) collect (each-4);
		
		create b from:geoms {
			free_space <- free_space - shape;
		}
		
		create a number:10 with:[dest::any_location_in(world.shape),location::any_location_in(free_space)] {
			// If pedestrian should avoid other or not
			avoid_other <- true;
			// Personal space
			shoulder_length <- 2#m;
			// Other agent species considered as pedestrian
			pedestrian_species <- [a];
			
		}
		
		do create_pedestrian_network;
		// Compute a target and a path toward it
		ask a { do cvp; }
	}
	
	action create_pedestrian_network(bool save <- false) {
		// See Pedestrian Skill model in Plugins models for more info on action signature
		list<geometry> generated_lines <- generate_pedestrian_network([],[free_space],true,false,0.1,0.01,true,1.0,0.1,0.0,0.5);
		
		create p from: generated_lines  {
			do initialize bounds:[free_space] distance: min(5.0,(b closest_to self) distance_to self) masked_by: [b] distance_extremity: 1.0;
		}
		
		network <- as_edge_graph(p);
		
		ask p { do build_intersection_areas pedestrian_graph: network; }
		
		if save {save p to: "../includes/pedestrian paths.shp" format:"shp";}
	}
	
}

species b { aspect default {draw shape.contour color:#black;}}

species a skills:[pedestrian] {
	
	point dest;
	
	reflex move {
		do walk;
		if (final_waypoint = nil) { do cvp; }
	}
	
	action cvp {
		do compute_virtual_path pedestrian_graph:network target: any_location_in(free_space) ;
	}
	
	aspect default {
		draw triangle(shoulder_length) color: #teal rotate: heading + 90.0;
		draw line(location,final_waypoint) color:#darkcyan;
		draw cross(0.6) at:final_waypoint color:#purple;
	}
}

species p skills: [pedestrian_road]{
	aspect default { 
		draw shape  color: #gray;
	}
}

experiment xp {
	float minimum_cycle_duration <- 0.05;
	output {
		display main {
			species a;
			species b;
			//species p;
		}
	}
}

experiment builtpedestrianet {
	action _init_ { create simulation {do create_pedestrian_network(true);}}
}