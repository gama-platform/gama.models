/**
* Name: Schelling
* Author: bgaudou
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model Schelling1

global {	
	int nb_people <- 2000;
	float rate_similar_wanted <- 0.4;
	float neighbours_distance <- 5.0;	
	
	init {
		create people number: nb_people;
	}
}

species people {	
	rgb color <- flip(0.5) ? #yellow : #red;
	bool is_happy;
	
	aspect circle {
		draw circle(2) color: color border: #black;
	}
}

experiment exp {
	output {
		display d {
			species people aspect: circle;
		}
	}
}