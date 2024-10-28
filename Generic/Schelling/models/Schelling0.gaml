/**
* Name: Schelling
* Author: bgaudou
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model Schelling1

global {	
	
	int envsize <- 50;
	float emptyprop <- 0.1;
	
	float redprop <- 0.5;
	
	init {
		create people number: envsize^2 - (envsize^2*emptyprop) {
			loc l <- shuffle(loc) first_with (each.empty);
			location <- l;
			l.empty <- false;
			color <- #red;
		}
		ask ((1-redprop) * length(people)) among people { color <- #blue; }
	}
}

grid loc height: envsize width: envsize { bool empty <- true; }

species people {
	rgb color;	
	aspect default { draw circle(world.shape.width/(envsize*2)) color: color; }
}

experiment exp type: gui {
	output {
		display d type:2d {
			grid loc lines:#black;
			species people;
		}
	}
}