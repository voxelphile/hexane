#version 450

#include "hexane.glsl"
#include "world.glsl"
#include "transform.glsl"
#include "voxel.glsl"

struct BuildWorldPush {
	BufferId world_id;
	BufferId transform_id;
	ImageId perlin_id;
};

decl_push_constant(BuildWorldPush)

#ifdef compute

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
	Image(3D, u32) perlin_image = get_image(3D, u32, push_constant.perlin_id);
	Buffer(World) world = get_buffer(World, push_constant.world_id);
	Buffer(Transforms) transforms = get_buffer(Transforms, push_constant.transform_id);

	u32 chunk = gl_GlobalInvocationID.x / CHUNK_SIZE + gl_GlobalInvocationID.y / CHUNK_SIZE * AXIS_MAX_CHUNKS + gl_GlobalInvocationID.z / CHUNK_SIZE * AXIS_MAX_CHUNKS * AXIS_MAX_CHUNKS;
	
	if (all(equal(mod(f32vec3(gl_GlobalInvocationID) / f32(CHUNK_SIZE), 1), vec3(0)))) {
		transforms.data[1 + chunk].position.xyz = vec3(gl_GlobalInvocationID);
	}

	VoxelChange change;
	change.chunk_id = world.chunks[chunk];
	change.id = u16(0);
	change.position = mod(f32vec3(gl_GlobalInvocationID), CHUNK_SIZE);
	
	f32 noise_factor = f32(imageLoad(perlin_image, i32vec3(gl_GlobalInvocationID.x, 32, gl_GlobalInvocationID.z) % i32vec3(imageSize(perlin_image))).r) / f32(~0u);

	f32 height = noise_factor * 4 + 32;

	//dunno why this is bugged.. if this statement isnt made like this
	//then grass spawns on chunk corners
	if(gl_GlobalInvocationID.y > height - 1 && gl_GlobalInvocationID.y < height + 1) {
		change.id = u16(2);
	} else if(gl_GlobalInvocationID.y < height) {
		change.id = u16(4);
	}

	voxel_change(change);
}

#endif

