/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model Move

global {
	init {
		create a number:10;
	}
}

species a {
	
	point destination <- any_location_in(world.shape);
	float speed <- 0.2 ;
	geometry shape <- circle(2);
	
	reflex move {		
		location <- location + {speed * ( destination.x - location.x), speed * (destination.y - location.y)};
	}
	
	aspect default {
		draw shape color:#teal ;
		draw cross(2) at_location destination color:#purple ;		
		draw line(location,destination) color:#darkcyan end_arrow: 2 ;
	}
	
}


experiment xp {
	output {
		display main {
			species a;
		}
	}
	
}