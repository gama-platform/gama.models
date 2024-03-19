/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	init {
		create a number:10 with:[dest::any_location_in(world.shape)] {
			// If pedestrian should avoid other or not
			avoid_other <- true;
			// Personal space
			shoulder_length <- 2#m;
			// Other agent species considered as pedestrian
			pedestrian_species <- [a];
		}
		
	}
	
}


species a skills:[pedestrian] {
	
	point dest;
	geometry shape <- circle(2);
	
	reflex move {
		do walk_to target:dest;
		if location distance_to dest < 1#m {dest <- any_location_in(world.shape);}
	}
	
	aspect default {
		draw triangle(shoulder_length) color: #teal rotate: heading + 90.0;
		draw line(location,dest) color:#darkcyan;
		draw cross(0.6) at:dest color:#purple;
	}
}

experiment xp {
	float minimum_cycle_duration <- 0.05;
	output {
		display main {
			species a;
		}
	}
	
}