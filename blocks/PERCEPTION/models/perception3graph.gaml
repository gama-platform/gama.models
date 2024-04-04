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
	
	graph<a,unknown> g <- graph([]);
	
	init {
		create a number:10;
//		g <- generate_complete_graph(false,list(a));
//		write g;
		
		
//		g <- graph([]);
		
		loop agt over: a {
			add node(agt) to: g;
		}
		
		loop i from: 0 to: length(g.vertices) - 2 {
			loop j from: i+1 to: length(g.vertices)-1 {
				write sample(i,j);
				add edge(g.vertices[i],g.vertices[j]) to: g;
			}
		} 
		
		write g;
		
		caller <- any(a);
		
		write sample(g successors_of caller);
//		ask g successors_of caller collect a(each) {
		ask g successors_of caller {
			write sample(self);
			onsight <- true;
		}
		
		using g {
			write caller neighbors_at 1;
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
		if self=caller {draw square(3) color:color;}
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
