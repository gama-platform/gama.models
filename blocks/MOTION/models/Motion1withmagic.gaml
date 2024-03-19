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

species a skills:[moving] {
	
	geometry shape <- circle(2);
	
	reflex move {
		do wander amplitude:90;
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