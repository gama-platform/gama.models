/**
 *  cabbages
 *  Author: bgaudou
 *  Description: 
 */

model cabbages

global {

	float growth_rate <- 0.2 ;
	float max_carrying_capacity <- 10.0;

	init {
		create goat number: 3;
		create wolf number: 10;
	}
}

species wolf {
	plot my_plot;
	init {
		my_plot <- one_of(plot where (each.is_free = true));
		location <- my_plot.location;
		my_plot.is_free <- false;
	}
	
	reflex move {
		plot next_plot <- one_of(my_plot.neighbors where(each.is_free = true));
		my_plot.is_free <- true;
		next_plot.is_free <- false;
		my_plot <- next_plot;
		location <- next_plot.location;
	}	
	
	aspect redCircle {
		draw circle(1) color: #red;
	}
}

species goat {
	plot my_plot;
		
	init {
		my_plot <- one_of(plot where (each.is_free = true));
		location <- my_plot.location;
		my_plot.is_free <- false;
	}
	
	reflex move {
		plot next_plot <- one_of(my_plot.neighbors where(each.is_free = true));
		my_plot.is_free <- true;
		next_plot.is_free <- false;
		my_plot <- next_plot;
		location <- next_plot.location;
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
