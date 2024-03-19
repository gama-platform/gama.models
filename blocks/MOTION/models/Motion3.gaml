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
		create a number:10;
	}
	
}

species a {
	
	point destination <- any_location_in(world.shape);
	float speed <- 0.2;
	geometry shape <- circle(2);
	
	reflex move {		
		location <- {(1-speed) * location.x,(1-speed) * location.y} + 
						{speed * destination.x, speed * destination.y};
	}
	
	aspect default {
		draw shape color:#teal;
		draw line(location,destination) color:#darkcyan;
		draw cross(0.6) at:destination color:#purple;
	}
	
}


experiment xp {
	output {
		display main type:2d {
			species a;
		}
	}
	
}