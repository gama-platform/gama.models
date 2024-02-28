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
	float reproduction_threshold <- 20.0;

	//definiton of the file to import
	file grid_data <- file('../includes/hab10.asc') ;
	
	//computation of the environment size from the geotiff file
	geometry shape <- envelope(grid_data);	

	init {
		create goat number: 3;
		create wolf number: 100;
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
	
	reflex reproduce when: energy >= reproduction_threshold {
		plot plot_for_child <- one_of(my_plot.neighbors where(each.is_free = true));
		
		if(plot_for_child != nil) {
			create species(self) number: 1 {
				do move_to_cell(plot_for_child);
				self.energy <- myself.energy / 2;
			}
			energy <- energy / 2;
		}
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
	
	reflex move {
		plot next_plot <- nil;
		
		list<plot> neigh <- my_plot.neighbors where(!empty(goat inside each ));
		if(empty(neigh)) {
			next_plot <- one_of(my_plot.neighbors where(each.is_free = true));
		} else {
			next_plot <- one_of(neigh);
			goat victim <- one_of(goat inside next_plot);
			energy <- energy + victim.energy;
			ask victim {
				write "" + self + " will die";
				do die;
			}			
		}

		do move_to_cell(next_plot);
	}
	
	aspect redCircle {
		draw circle(1000) color: #red;
	}
}

species goat parent: animal {	
	
	reflex eat_cabbage {
		float cab <- min([max_cabbages_eat, my_plot.biomass]);
		energy <- energy + cab;
		my_plot.biomass <- my_plot.biomass - cab;
	}	
	
	aspect blueSquare {
		draw square(1000) color: #blue;
	}
}

grid plot file: grid_data neighbors: 8 {
// grid plot height: 30 width: 30 neighbors: 8 {

	float biomass;
	float carrying_capacity;
	rgb color <- rgb(0,255*biomass/max_carrying_capacity,0)
		update: rgb(0,255*biomass/max_carrying_capacity,0);		
		
	bool is_free <- true;
	
	init {		
		carrying_capacity <- grid_value;
		//carrying_capacity <- rnd(max_carrying_capacity);		
			
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
		
		display plots {
			chart "Nb animals" type: series {
				data "#wolves" value: length(wolf);
				data "#goats" value: length(goat);
			}
		}
	
	}
}
