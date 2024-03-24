/**
* Name: perception1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model perception1

/* Insert your model definition here */

global {  
	
	a caller;
	float perception <- 10#m;
	
	init {
		create a number:100;
		caller <- any(a);
	}
	
}

species a {
	
	rgb color <- rnd_color(255);
	bool onsight -> self distance_to caller < perception;
	
	aspect default {
		draw circle(1) color:blend(color,#transparent,onsight?1:0.1);
		if self=caller { draw circle(perception).contour color:#black; }
	}
	
	reflex rndmove when:self!=caller {
		location <- any_location_in(world.shape);
	}
}

experiment xp { 
	float minimum_cycle_duration <- 0.1;
	output {
		display main {
			species a;
		}
	}
}