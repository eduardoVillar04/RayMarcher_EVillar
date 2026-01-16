# Roadmap
### Milestone 1 – Dec 17 to Dec 24 
- Build the foundation of the ray marcher and Custom Render Feature. 
- Ray marcher renders a single primitive on screen through a Custom Render Feature.
> Completed 23/12/2025 with commit: "Shader rays behave using unity main camera logic"

### Milestone 2 – Dec 25 to Dec 31 
- Allow scene interaction and ray marcher objects.
- Multiple objects can be added, moved, and rendered through the ray marcher interactively.
> Completed 27/12/2025 with commit: "RMManager send buffer with RMObjs params to shader for SDF evaluation"

### Milestone 3 – Jan 1 to Jan 4  
- Integrate ray marcher with Unity geometry and depth buffer.
- Ray-marched objects appear correctly behind Unity meshes and do not render over them incorrectly.
> Completed 29/12/2023 with commits: "Added basic depth-based occlusion to ray marching shader" (24/12/25) and "Implemented smooth subtraction and intersection" (29/12/25)

### Milestone 4 - Jan 5 to Jan 14
Bonus Features (Fractals, Blending, Clouds)
- Blending -> Completed 29/12/25 with commit "Implemented smooth subtraction and intersection"
- Fractals 
  - Infinite spheres -> Completed 31/12/25 with commit "Add configurable repetition cell to ray marcher"
  - Merger Sponge -> Completed 31/12/25 with commit "Add Menger sponge support to RayMarcherObject"
- Volumetric clouds -> Completed 12/01/26 with commit "fixed clouds rendering behind camera"
> Completed 12/01/2026 with commits:
> "Add configurable repetition cell to ray marcher" (29/12/25)
> "Add configurable repetition cell to ray marcher" (31/12/25)
> "Add Menger sponge support to RayMarcherObject" (31/12/25)
> "fixed clouds rendering behind camera" (12/01/26)

### Milestone 5 - Jan 15 to Jan 16
Prepare the final presentation and clean up.


# Raymarcher package git
> https://github.com/eduardoVillar04/raymarcher-package.git
