/**
* Name: Continuous
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Continuous

global {
	init {
		create people number: 10;
		
		write world.shape;
		write world.shape.width;
		write world.shape.height;
	}
}

species people {
	aspect default {
		draw circle(2) color: #blue;
		if self.index = 0 {
			draw line(self,people[1]) color: #black;
		}
	}
}



experiment name type: gui {
	output {
		display "My display" type: 3d { 
			species people;
		}
	}
}