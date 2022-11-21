#version 450

#include "hexane.glsl"
#include "octree.glsl"
#include "transform.glsl"
#include "bits.glsl"
#include "raycast.glsl"

#define CHUNK_SIZE 8

#define VERTICES_PER_CUBE 6

struct DrawPush {
	BufferId info_buffer_id;
	BufferId camera_buffer_id;
	BufferId vertex_buffer_id;
	BufferId transform_buffer_id;
	BufferId bitset_buffer_id;
};

USE_PUSH_CONSTANT(DrawPush)
	
#ifdef vertex

vec3 offsets[8] = vec3[](
        vec3(0, 0, 1),
        vec3(0, 1, 1),
        vec3(1, 1, 1),
        vec3(1, 0, 1),
        vec3(0, 0, 0),
        vec3(0, 1, 0),
        vec3(1, 1, 0),
	vec3(1, 0, 0)
);

struct Vertex {
	vec4 position;
	u32vec4 normal;
	vec4 color;
	vec4 ambient;
};

DECL_BUFFER_STRUCT(
	CameraBuffer,
	{
		mat4 projection;
	}
)

DECL_BUFFER_STRUCT(
	VertexBuffer,
	{
		u32vec4 vertex_count;
		Vertex verts[255680];
	}
)

layout(location = 0) out vec4 position;
layout(location = 1) flat out u32vec4 normal;
layout(location = 2) flat out vec4 color;
layout(location = 3) flat out vec4 ambient;
layout(location = 4) out vec4 uv;

void main() {
	BufferRef(CameraBuffer) camera_buffer = buffer_id_to_ref(CameraBuffer, BufferRef, push_constant.camera_buffer_id);
	BufferRef(TransformBuffer) transform_buffer = buffer_id_to_ref(TransformBuffer, BufferRef, push_constant.transform_buffer_id);
	BufferRef(VertexBuffer) vertex_buffer = buffer_id_to_ref(VertexBuffer, BufferRef, push_constant.vertex_buffer_id);

	u32 i = gl_VertexIndex / VERTICES_PER_CUBE;
	u32 j = gl_VertexIndex % VERTICES_PER_CUBE;
	
	position = vertex_buffer.verts[i].position;
	normal = vertex_buffer.verts[i].normal;
	color = vertex_buffer.verts[i].color;
	ambient = vertex_buffer.verts[i].ambient;
	
	vec2 uvs[6] = vec2[](
		vec2(0, 0),
		vec2(0, 1),
		vec2(1, 1),
		vec2(0, 0),
		vec2(1, 1),
		vec2(1, 0)
	);

	if(normal.xyz == u32vec3(0, 0, 1)) {
		u32 i[6] = u32[](1, 0, 3, 1, 3, 2);
	
		position.xyz += offsets[i[j]];	
		uv.xy = vec2(uvs[j].x, 1 - uvs[j].y);
	}
	
	if(normal.xyz == u32vec3(0, 0, -1)) {
		u32 i[6] = u32[](4, 5, 6, 4, 6, 7);
		
		position.xyz += offsets[i[j]];	
		uv.xy = uvs[j].xy;
	}
	
	if(normal.xyz == u32vec3(1, 0, 0)) {
		u32 i[6] = u32[](2, 3, 7, 2, 7, 6);
		
		position.xyz += offsets[i[j]];	
		uv.xy = 1 - uvs[j].yx;
	}
	
	if(normal.xyz == u32vec3(-1, 0, 0)) {
		u32 i[6] = u32[](5, 4, 0, 5, 0, 1);
		
		position.xyz += offsets[i[j]];
		uv.xy = vec2(1 - uvs[j].y, uvs[j].x);
	}
	
	if(normal.xyz == u32vec3(0, 1, 0)) {
		u32 i[6] = u32[](6, 5, 1, 6, 1, 2);
		
		position.xyz += offsets[i[j]];	
		uv.xy = vec2(uvs[j].x, 1 - uvs[j].y);
	}
	
	if(normal.xyz == u32vec3(0, -1, 0)) {
		u32 i[6] = u32[](3, 0, 4, 3, 4, 7);
		
		position.xyz += offsets[i[j]];	
		//TODO
		uv.xy = uvs[j].xy;
	}
	
	Transform transform = transform_buffer.transform;
			
	gl_Position = camera_buffer.projection * inverse(compute_transform_matrix(transform)) * position;
}

#elif defined fragment

#define SHOW_UV false
#define SHOW_RGB_STRIATION false
#define SHOW_NORMALS false
#define SHOW_AO true

layout(location = 0) in vec4 position;
layout(location = 1) flat in u32vec4 normal;
layout(location = 2) flat in vec4 color;
layout(location = 3) flat in vec4 ambient;
layout(location = 4) in vec4 uv;

layout(location = 0) out vec4 result;

void main() {
    	result = color;
	
	BufferRef(BitsetBuffer) bitset_buffer = buffer_id_to_ref(BitsetBuffer, BufferRef, push_constant.bitset_buffer_id);
	
	float ao = 0;

	ao = mix(mix(ambient.z, ambient.w, uv.y), mix(ambient.y, ambient.x, uv.y), uv.x);

	vec3 sun_position = vec3(1000, 2000, 100);
	
	Ray ray;
	ray.bitset_buffer_id = push_constant.bitset_buffer_id;
	ray.origin = position.xyz + normal.xyz * EPSILON * EPSILON;
	ray.direction = normalize(sun_position - ray.origin);
	ray.max_distance = 5;

	RayHit ray_hit;

	bool success = ray_cast(ray, ray_hit);
	
	if(SHOW_UV) {
		result = vec4(0, 0, 0, 1);
		result.xy = uv.xy;
	}

	if(SHOW_RGB_STRIATION) {
#define STRIATE 8
		result.xyz = mod(position.xyz, STRIATE) / STRIATE;
	}
	
	if(SHOW_NORMALS) {
		result.xyz = normal.xyz;
		if(normal.x < -1 + EPSILON || normal.y < -1 + EPSILON || normal.z < -1 + EPSILON ){
			result.xyz = 1 - result.xyz;
		}
	}
	
	if(SHOW_AO) {
		result.xyz = result.xyz - vec3(1 - ao) * 0.25;
	}

	if(success) {
		result.xyz *= 0.5;
	}
}

#endif
