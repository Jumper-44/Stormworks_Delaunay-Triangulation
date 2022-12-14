# Stormworks_Delaunay-Triangulation

Doing 2.5d Delaunay triangulation on “incrementive” point cloud and renderes the terrain with augmented reality.
2.5d meaning that the triangulation is done in 2d, but each point still has a height value which is used when rendering, so 2.5d for a terrain heightmap.

This is made to work in the game of Stormworks: Build and Rescue.
Vehicle on steam workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=2871941850


## CameraTransform, Delaunay & Render
In short of the involved algorithms, then a k-d tree with only insert and nearest neighbor is used for the point cloud.
The Delaunay triangulation is done with the Bowyer–Watson algorithm, in which a quadtree is used to store the triangles (No duplicates in tree).
When searching through the quadtree for illegal triangles then the first illegal triangle that is found is returned and then uses neighboring triangles search to find the whole polygonal hole of illegal triangles. Should more or less make the triangulation O(n log n) on average, instead of O(n*n), due to search being O(log n) on average (log base 2).
The quadtree is also used for frustum culling chunks of triangles to render.

In Stormworks there is a limit of 4096 chars for each LUA script (Also in a sandboxed environment, meaning no metatables) in vehicles, which makes it a hassle to implement good/readable and efficient code. In this example then efficiency is meant as being able to implement data structures, using 'local', 'if statement', 'do end' scopes and functions in general annoying due to the small char limit. For average code then this is usually not an issue and if it does start becoming then using a minifier mostly does the job. So due to the char limit this uses 3 scripts. Also a slight annoyance in microcontrollers is that every new node introduces a tick delay, so also accounting for 4 ticks delay. (60 tick a second)



### CameraTransform.lua
The boolean 'renderOn' is sent to every script, in which rendering, adding new points and triangulation is only done when it is 'true'.

The first script calculates the cameraTransform matrix, which is a 4x4 matrix consisting of the transposed rotation matrix (transposed rotation matrix has the same properties as the inverse rotation matrix) and the perspective projection matrix. The perspective projection matrix is asymmetrical to account for the player head position to achieve augmented reality, in which a boolean 'isFemale' is used to check if it should account for the difference in male and female player position.
An important note if you are familiar with the cameraTransform is that this one is looking down the +Y axis, which is forward, +X is right and +Z is up.
Projects to clip space and after the homogeneous division for screen space then: x|y:coordinates [-1;1], z:depth [0;1], w:homogeneous coordinate.
Usually the camera is looking down -+z axis, but due to the compass in this game pointing towards +y, then it is just more straightforward to do so, which is also why the rotation matrix extrinsic rotation order is rotation around the y-axis (roll) then x-axis (pitch) and lastly z-axis (yaw).

Mathematically wise then the matrix multiplication for the rotation matrix is: rotZXY = rotZ * rotX * rotY, just in case the name ordering for ZXY was confusing.

It would be easy (assuming familiarity with the math involved for cameraTransform for it to be 'easy', but coding wise is) to remove the player head offset to get a normal camera and then can also change the perspective projection matrix to a orthogonal projection matrix if needed, but remember to change the matrix contents to look down the +y axis.

The cameraTransform and gps is sent through the 2nd script, which parses it to the 3rd, which does the rendering.
This takes up the composite number channels 1-16 for cameraTransform(without translation) and gps.

This script also uses k-d tree to store points, it only has insert and nearest neighbor search and is used for the sole reason of having an O(log n) search time on average instead of O(n). The nearest neighbor search is used when trying to add a new point, if the distance to the nearest saved point is less than a set value, then it is ignored, which makes a filter to control the density of the point cloud and therefore less triangles.

If the triangulation is ignored, then this would also do great for a normal LIDAR scan, to limit the density of points and therefore better performance.

If the point is accepted then it is inserted to the k-d tree and sent to the next script.
The 3d point occupies the 17-19 number composite. The 20th number composite is also used to pass through the color alpha value for rendering to the 2nd script which parses it to the 3rd.

The way the next scripts accept a new point is by checking if 'x' and 'y' is not equal to 0 ('z' is height). So when sending a new point its coordinates are only pulsed in a single tick else it just sends 0 for 17-19 number composite. That is to say if you change the way points are calculated/accepted, then the only notice that is needed for the next script to accept a point is just noting that when no new points are added then send 0.


### Delaunay.lua
If the 'x' and 'y' is not equal to 0 then it is accepted as a 3d point and added to a table. Every point also has an 'id' number, which is just its index to the table.
The 3 numbers making up the point is also sent to the third script, such that both this and the next script has an identical copy of the table containing points.
More about that reason after the triangulation.

The Delaunay triangulation algorithm used is the Bowyer-Watson algorithm, which is an incremental algorithm, meaning that it adds new points to the triangulation one by one and effectively keeps the intermediate calculations, so it only removes the illegal triangles and add new ones to the triangulation while keeping the rest as is.
By illegal means that the new point fits inside the circumcircle of the 3 vertices making up the triangle.
I won't step wise go into how the Bowyer-Watson algorithm works and the specifics of what a Delaunay triangle is, but just the way it is used.

The algorithm by itself takes O(n*n) time to do, which means that for every point that is added to the triangulation it has to check every triangle in the mesh if it is illegal.
So to make it more efficient would be to bring down the search time of finding illegal triangles, which is why a quadtree is used to store the triangles.
The quadtree has no duplicates, so it is easy to add and remove triangles, as its job is just to bring down the search time (In this script, the next one also uses a quadtree with no duplicates, but different functionality, mainly the frustum culling the quadtree).

When searching through the quadtree for illegal triangles then the first illegal triangle that is found is returned. All illegal triangles makes up a polygon, so by having each triangle have a reference to its 3 neighbors (Of course every triangle doesn't have a neighbor, but that case is handled), then it is easy/fast to traverse all neighboring triangles to check if they are illegal, which makes the search for all triangles fast compared to checking every triangle in the mesh. This is more or less O(log n) search time on average, bringing the triangulation to O(n log n).

The triangles winding order of its 3 vertices is counter clockwise (CCW), which originally was done for the sole reason of being able to back-face cull triangles, AKA remove and therefore not draw the triangles that are not facing the camera, but for consistency with neighboring triangles, then it is defined such that if you start at a point of the triangle, say its 2nd: t[2], then the edge counter clockwise for that point is the neighboring triangle accessed by t.neighbor[2]. Having a winding order for neighboring triangles too is useful in code. It could also have been clockwise (CW) winding order, but the point is that it needs to be consistent for all triangles.

Then the Bowyer-Watson algorithm does its magic and the newly added triangles are made sure to have their neighboring triangle references setup correctly.

Now back to the reason of why this and the next script needs an identical table holding points with the same index, and that is because this and the next script needs to have an exact copy of all the triangles as well, well almost, triangles which shares a vertex with the 'super triangle' (a term used by the triangulation algorithms) are omitted, but else then a delta change of triangles is sent to the next script. The composite channel 1-16 is made up of the cameraTransform and gps, 17-19 are the new point xyz and the 20th is the color alpha value. So the remaining free space is 21-32 making '12*32bit = 384 bits' of information every tick, and also the boolean composite channel is available.

When a triangle is created then it doesn't 'own' its vertices, but just references the point/table, which memory wise is great, but also makes it easier to send the triangle information to the next script, since every vertex has an 'id', which is its index to the 'global' table holding every point, so it is only the 'id' of every 3 vertices making up a triangle that needs to be sent, and a bool for if it is getting removed or added. So during the triangulation every action is queued/logged in a table to be sent for the next script. (Every action of triangle add/remove except of triangles that shares a vertex with the 'super triangle')
If the bool of whether the triangle is added or removed is sent via the boolean composite channel, then to send a triangle is 3 32bit integers, which is the id/index to the 'global' point table, then 12/3 is 4 triangles which are added or removed per tick, which just isn't that much or enough to keep up, so let us double it.
Every number in a composite is 32bit number, so if we halves it to 16bits unsigned integer by bit shifting then we have a max id/index number of 2^16-1 = 65535, which effectively doubles the sendrate to 8 triangles per tick, which is enough. There is just the case of the 'global' point table shouldn't exceed 65535 else it will crash, which a forced halt of adding new points would stop exceeding that number, but I haven't done so.
Also it probably won't exactly crash the script, but when this script has a 'id' value of 65535+1, then due to it being an unsigned int, then it would just wrap around and send the point 'id' to the next script as 0 and going up from there, in which until a triangle that is affected is getting removed, then it may crash.
Another way to say is I haven't tested that case nor handled it, just know it is there.


### Render.lua
Receives the cameraTransform, gps, new point and triangles update.

The new point is added to the table to get an identical copy of the same points to the earlier script, effectively making a 'global' table for reading points.
The triangles update is handled to construct triangles that are to be added or removed from the quadtree (no duplicates).

The color of a triangle is decided when it is created, so first it is decided if it should be water or ground colored, which is done by checking if 2-3 of the vertices has a height of 0 or less for water, else ground. 2 colors are written for water and ground, which is what it is when flat and steep. Then the dot product of the normalized surface normal and a vector representing the sun direction is done, which gives a value between -1 to 1, but it is squared to get absolute value and a better curve, so 0-1. That value is used to lerp between the flat(1) and steep(0) color variation and after the lerp then the lerp’ed color is shaded with the same dot product value.

The quadtree is used for frustum culling, so only triangles that are potentially or fully in view are checked instead of everything in memory, which brings the amount of triangles that are checked down substantially.
Potentially and fully visible triangles are added to the 'triangle_buffer' table, in which while the quad nodes are being traversed and adding triangles to the buffer,
then if '#triangle_buffer' is greater than a set parameter, then it will only add every second triangle that lies in a quad node, which is done for performance to make the amount of triangles added to the buffer way less. It is done this way to add only every second triangle instead of fully discarding a quad node. Ideally then it would use level of detail (LOD) to keep the amount of triangles down, especially at distance, since the amount of pixels on monitors aren't great, but no idea how that would be done with the minimal amount of chars I have left.

After the 'triangle_buffer' has been filled, which is not done every tick, as there is a parameter for the 'triangle_buffer_refreshrate' in ticks. So the quadtree frustum culling is done more like 2-4 times per second, due to the amount of triangles that needs to be checked is still quite a lot once a wide scan has been done, so doing it this way is a major performance boost.

So after the 'triangle_buffer' has been filled from the quadtree frustum culling, then every triangle in the buffer has its vertices transformed by the cameraTransform matrix, and an important note is that it is accounting for shared vertices between triangles, so the same vertex is not transformed twice. Then a series of if statements are done, in which if they fail then the triangle is discarded from the 'triangle_buffer'.
If any of the triangles vertices are outside of the near and far plane, then discard it. If none of the 3 vertices is in view/frustum then discard it.
Then there is also a check for back-face culling, which is if the triangle is facing the camera, which is only done once every time the 'triangle_buffer' is refreshed and filled anew from the quadtree.

Then the 'triangle_buffer' is sorted with painter's algorithm, which sorts the table based on the triangles depth, so the first triangles that are drawn are the furthest away and then draws closer to the camera. Once the triangles are sorted, then there is a last check for discarding triangles before they are drawn.
There is a parameter 'max_drawn_triangles', so if the amount of triangles in the buffer is greater than that parameter then it will discard every triangle in the buffer till it has fewer triangles in the buffer than the max amount of triangles allowed to be drawn. Since the buffer has been sorted, then when it is discarding triangles, then it will start from furthest away.



## Post Note
This was written in a single sitting of many hours, so while it does more or less explain what is done, some things become a little rant-like and therefore might not properly convey what is happening or be hard to understand.
