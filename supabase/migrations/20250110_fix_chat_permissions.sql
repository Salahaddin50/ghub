-- Grant execute permissions for chat functions
GRANT EXECUTE ON FUNCTION public.send_message(TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_message_as_read(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(UUID, UUID[]) TO authenticated; 