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
	
	graph<a,unknown> g;
	
	init {
		
		create a number:20;
        g <- graph([]);
        
        loop agt over: a {
            add node(agt) to: g;
        }
        
        loop i from: 0 to: length(g.vertices) - 2 {
        	add edge(g.vertices[i],g.vertices[(i+1) mod length(g.vertices)]) to: g;
            loop j from: i+1 to: length(g.vertices)-1 {
                if flip(0.01) {add edge(g.vertices[i],g.vertices[j]) to: g;}
            }
        }
		
		caller <- any(a);
		
		ask g neighbors_of caller {onsight <- true;}
		
		
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