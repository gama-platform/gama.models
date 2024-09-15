/**
* Name: Schelling
* Author: bgaudou
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model Schelling2

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
	
	list<people> neighbours update: people at_distance neighbours_distance;
	
	reflex compute_similarity {
		float rate_similar <- 0.0;
		if(empty(neighbours)) {
			rate_similar <- 1.0;
		} else {
			int nb_neighbours <- length(neighbours);
			int nb_neighbours_sim <- neighbours count (each.color = color);
			rate_similar <- nb_neighbours_sim / nb_neighbours;
		}
		
		is_happy <- rate_similar >= rate_similar_wanted;
	}
	
	reflex move when: not(is_happy) {
		location <- any_location_in(world);
	}
	
	aspect circle {
		draw circle(2) color: color border: #black;
	}
}

experiment exp type: gui {
	output {
		display d {
			species people aspect: circle;
		}
		
		display c1 {
			chart "happySeries" type: series {
				data "happies" value: people count each.is_happy color: #blue;
				data "no-happies" value: people count !each.is_happy color: #red;
				
			}
		}
		display c2 {
			chart "happySeries" type: pie {
				data "happies" value: people count each.is_happy color: #blue;
				data "no-happies" value: people count !each.is_happy color: #red;
				
			}
		}	
		
		monitor "nb happies" value: people count each.is_happy;
	}
}