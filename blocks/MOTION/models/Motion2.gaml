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
	
	geometry shape <- circle(2);
	
	reflex move {
		location <- any_location_in(location buffer 2 inter world.shape);
	}
	
}

experiment xp {
	output {
		display main {
			species a;
		}
	}
	
}