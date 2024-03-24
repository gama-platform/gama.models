/**
* Name: perception1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model perception1

/* Insert your model definition here */

global {  
	
	init {
		create a;
	}
}

species a {
	
	init {
		location <- world.shape.centroid;
	}
	
	aspect default {
		point l <- location+{2,0};
		draw circle(1) color:#black;
		loop i over:a.attributes {
			draw i+" = "+(self[i]) at:l color:#black; l <- l + {0,2};
		}
	}
}

experiment xp { 
	output {
		display main type:2d {
			species a;
		}
	}
}