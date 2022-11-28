struct EntityInput {
	bool up;
	bool down;
	bool left;
	bool right;
	bool forward;
	bool backward;
	vec4 look;
};

decl_buffer(
	Info,
	{
		f32 time;
		f32 delta_time;
		EntityInput entity_input;
	}
)
