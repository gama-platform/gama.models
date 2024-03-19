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
		create a number:10 with:[dest::any_location_in(world.shape)];
	}
	
}

species a skills:[moving] {
	
	point dest;
	geometry shape <- circle(2);
	
	reflex move {
		do goto target:dest;
		if location distance_to dest < 1#m {dest <- any_location_in(world.shape);}
	}
	
	aspect default {
		draw shape color:#teal;
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