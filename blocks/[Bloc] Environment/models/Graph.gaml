/**
* Name: Graph
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Graph

global {
	graph<people,unknown> g <- as_spatial_graph(directed(graph<people,unknown>([])));
	
	init {
		create people number: 10;
		
		loop p over: people {
			add node(p) to: g;		
		}
		
		loop p over: people {
			ask 4 among (people-self) {
				add edge(p,self) to: g;
			}
		}
		
		write g;
		
		people p <- any(g.vertices);
		p.color <- #red;
		
		write sample(p);
		write sample(g neighbors_of p);
		
		ask g successors_of p {
			self.color <- #yellow;
		} 	
		
		using topology(g) {
			write p distance_to people[3];
		}
		
		using topology(world) {
			write p distance_to people[3];
		}
		
	}
}

species people {
	rgb color <- #blue;
	
	aspect default {
		draw circle(2) color: color;
		loop neigh over: g successors_of self {
			draw line(self.location,neigh.location) color: #black end_arrow: 1;
		}
	}
}


experiment name type: gui {

	output {
		display "My display" { 
			species people;
		}
	}
}