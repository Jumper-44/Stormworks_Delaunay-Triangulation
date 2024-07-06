# Stormworks_Delaunay-Triangulation

![Gif of vehicle scanning/rendering the mountains.](<Images/synthetic vision.gif>)
[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2793934450)  
  
Done in the game Stormworks: Build and Rescue. Actively sampling LIDAR point data and store point cloud in a k-d tree. When trying to insert a new point, then nearest neighbor search is done in k-d tree to filter accepted points and control the maximum point cloud density.  
Incrementally doing 2.5D delaunay triangulation with new inserted points using Boywer-Watson algorithm in O(n logn) on average. A triangle from the delaunay triangulation is evaluated to be part of final mesh by testing the radius of the minimum enclosing circle of the triangle. If accepted then it gets colored/shaded once.  
Triangles part of final mesh are inserted in a quadtree to spatially partition them. No duplicates of triangles in quadtree, so if a triangle AABB is intersecting the edge of smaller/children quad nodes, then it stops traversing and is stored in that current node. The quadtree is frustum culled to quickly build a list of potentially visible triangles and discard definitely out of view triangles.  
A virtuel camera is implemented with an asymmetric perspective projection matrix to get augmented reality in game, and constructs a final 4x4 camera transform matrix as a camera with rotation and translation matrices. More info on camera implementation [here](https://github.com/Jumper-44/Stormworks_AR-3D-Render). Project triangles in list by frustum culled quadtree to clip space and clip out of view triangles. Sort list of visible triangles with Painter's algorithm, so triangle centroid depth sort, and finally draw triangles back to forth.  
And other stuff to handle Stormworks limitations/restraints.  
Implementation is in the folder [2.5d delaunay triangulation](<2.5d delaunay triangulation>).

<br></br>

Also a folder for [3d surface triangulation](<3d surface triangulation>). 3D Boywer-Watson algorithm and alpha shapes implementation. Experimental and only works in VSCode, if you can understand the unstructured testing environment.  

![3d surface triangulation](<Images/Concave hull.gif>)