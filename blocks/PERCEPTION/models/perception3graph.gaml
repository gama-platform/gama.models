/**
* Name: perception1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model perception1

/* Insert your model definition here */

global {  
	
	a caller;
	int perception <- 2;
	
	graph g;
	
	init {
//		create a number:100;
//		caller <- any(a);
		
		g <- as_spatial_graph(generate_complete_graph(10,false,a));
		
		caller <- any(a);
		
		write g successors_of caller;
		ask g successors_of caller collect a(each) {
			write sample(self);
			onsight <- true;
		}
		
//		using g {
//			ask caller neighbors_at perception {onsight <- true;}	
//		}
	}
	
}

species a {
	
	rgb color <- rnd_color(255);
	bool onsight <- false;
	
	aspect default {
		draw circle(1) color:blend(color,#transparent,onsight?1:0.1);
	}
	
}

experiment xp { 
	float minimum_cycle_duration <- 0.1;
	output {
		display main {
			species a;
			graphics edges { loop e over:g.edges {draw geometry(e) color:#black;} }
		}
	}
}