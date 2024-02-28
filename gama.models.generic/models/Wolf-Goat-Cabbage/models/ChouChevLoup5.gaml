/**
 *  cabbages
 *  Author: bgaudou
 *  Description: 
 */

model cabbages

global {

	float growth_rate <- 0.2 ;
	float max_carrying_capacity <- 10.0;
	float initial_energy <- 10.0;
	float max_cabbages_eat <- 2.0;

	init {
		create goat number: 3;
		create wolf number: 10;
	}
}

species animal {
	plot my_plot;
	float energy <- initial_energy;
	
	init {
		plot random_plot <- one_of(plot where (each.is_free = true));
		do move_to_cell(random_plot);
	}
	
	reflex move {
		plot next_plot <- one_of(my_plot.neighbors where(each.is_free = true));
		do move_to_cell(next_plot);
	}	
	
	reflex energy_loss {
		energy <- energy - 1;
	}
	
	reflex death when: energy <= 0.0 {
		do die;
	}
	
	action move_to_cell(plot new_plot) {
		if(my_plot != nil) {
			my_plot.is_free <- true;		
		}
		new_plot.is_free <- false;
		my_plot <- new_plot;
		location <- new_plot.location;		
	}
		
}

species wolf parent: animal {
	aspect redCircle {
		draw circle(1) color: #red;
	}
}

species goat parent: animal {	
	
	reflex eat_cabbage {
		float cab <- min([max_cabbages_eat, my_plot.biomass]);
		energy <- energy + cab;
		my_plot.biomass <- my_plot.biomass - cab;
	}	
	
	aspect blueSquare {
		draw square(2) color: #blue;
	}
}

grid plot height: 30 width: 30 neighbors: 8 {

	float biomass;
	float carrying_capacity;
	rgb color <- rgb(0,255*biomass/max_carrying_capacity,0)
		update: rgb(0,255*biomass/max_carrying_capacity,0);		
		
	bool is_free <- true;
	
	init {		
		carrying_capacity <- rnd(max_carrying_capacity);		
		biomass <- rnd(carrying_capacity);
		color <-  rgb(0,255*biomass/max_carrying_capacity,0);	
	}	
	
	reflex grow {
		if(carrying_capacity != 0){
			biomass <- biomass * (1 + growth_rate * (1 - biomass/carrying_capacity));	
		}
	}
}


experiment cabbagesExp type: gui {
	output {
		display biomass {
			grid plot border: #black;
			species wolf aspect: redCircle;
			species goat aspect: blueSquare;
		}
	}
}
