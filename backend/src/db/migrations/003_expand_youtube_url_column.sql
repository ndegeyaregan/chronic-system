-- ============================================================
-- 003: Expand YouTube URL column to support full URLs
-- ============================================================

ALTER TABLE partner_videos 
ALTER COLUMN youtube_video_id TYPE VARCHAR(500);

COMMENT ON COLUMN partner_videos.youtube_video_id IS 'Stores full YouTube URLs or video IDs (e.g., https://www.youtube.com/watch?v=dQw4w9WgXcQ or dQw4w9WgXcQ)';
