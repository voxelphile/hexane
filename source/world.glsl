#define CHUNK_SIZE 128
#define AXIS_MAX_CHUNKS 8

decl_buffer(
	World,
	{
		ImageId chunks[1000];
	}
)
