# Stormworks_Delaunay-Triangulation

![Gif of vehicle scanning/rendering the mountains.](<Images/synthetic vision.gif>)
[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2871941850)  
  
Done in the game Stormworks: Build and Rescue. Actively sampling Using an array of laser distance sensor to get points, which is added to a point cloud. For every new point I try to add, I check the distance to the nearest point in the data set that is stored. If the distance is not bigger than a set minimum threshold then I ignore the point.  
That just makes sure some points are not in the same place or too clumped together.  
There's also a distance threshold for when the terrain is flat to better control the triangle density where it wouldn't help to get highere quality mesh.  

I use a [k-d tree](https://en.wikipedia.org/wiki/K-d_tree) structure (and another similar stucture: ball tree) to efficiently search the distance to a nearest point.  

Then after getting a point, instead of directly drawing the point cloud like LIDAR, I triangulate it with 2.5D [delaunay triangulation](https://en.wikipedia.org/wiki/Delaunay_triangulation), this [algorithm](https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm) specifically.  

The algorithm works with n dimensions, but not that simple to work in 3D, as you get the dimensional [simplex](https://en.wikipedia.org/wiki/Simplex), so tetrahedra. Therefore it's done in 2D, so the height is ignored during triangulation, but used again when drawing, so 2.5D.  
The algorithm is incremental, which is to say that I add one point at a time to the mesh, and use the intermediate calculations, so I'm not starting the triangulation over from scratch every time a new point is added.  

The color/shading of a triangle is chosen once, which is first determined if it should be water or ground color by if triangle centroid center (average of 3 vertices altitude) is under 0 altitude, then it's colored as water else ground.  
Then color is decided using the triangle normal vector Y/up-value and a chosen color gradient (for water or ground) in property setting.  
The shading is done with dot product of the triangle normal and a fixed directional light vector.  

Then the triangle centroid point (avg. of vertices) is added to a [Ball Tree](https://en.wikipedia.org/wiki/Ball_tree) data structure, incrementally and self balancing implementation.  
The data structure is used to spatially partition a batch of 4-7 triangles in spheres, such that it is fast to frustum cull and either accept triangles inside or throw away during tree traversal, without needing to test every triangle inside.  
Frustum culling happens every 15 tick unless changed in property setting and work is dynamically split up during those ticks.  
During culling then when upon a leaf node where triangles are stored, then the sphere is projected onto the screen and if the size is less than pixel culling threshold it removes some of the triangles in the batch.  

Finally with single list of triangles roughly in view after frustum culling then it is first checked per triangle if in infront of camera and within render distance else deleted from list.  
And there's a setting to cap max rendered triangles, so it tries to roughly shuffle some of the triangles higher than threshold into the rendered list before removing everything above cap, which roughly results in a terrain mesh with somewhat evenly spaced holes.  
If this happens then a good option is to render in wireframe mode as triangles are probably really densely packed anyway.  
Triangles in view are then projected to the screen and finally drawn.  

Designed for either a monitor or Head Mounted Display with player in compact seat (in game).  
Of course more things involved but the most important things explained.  

<br></br>

A virtuel camera is implemented with an asymmetric perspective projection matrix to get augmented reality in game, and constructs a final 4x4 camera transform matrix as a camera with rotation and translation matrices. More info on camera implementation [here](https://github.com/Jumper-44/Stormworks_AR-3D-Render). Implementation is in the folder [2.5d delaunay triangulation](<2.5d delaunay triangulation>).

<br></br>

The laser sampling system is independently done from the triangulation and rendering system, as in done in different lua scripts and it controls the laser sensors XY pivots and outputs 3D points which the triangulation system then gets as input. In [GimbalLaser](<GimbalLaser>).

<br></br>

Also a folder for [3d surface triangulation](<3d surface triangulation>). 3D Boywer-Watson algorithm and alpha shapes implementation. Experimental and only works in VSCode, if you can understand the unstructured testing environment.  

![3d surface triangulation](<Images/Concave hull.gif>)