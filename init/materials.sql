--Materials
--Id = 1 Media_d = 1
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(1, 'wav', 'medium', 1);
--Id = 2 Media_d = 1
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(1, 'mp3', 'low', 1);
--Id = 3 Media_d = 3
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(3, 'bmp', 'high', 2);
--Id = 4 Media_d = 3
INSERT INTO materials(media_id, format, quality, license_id)
  VALUES(3, 'jpg', 'medium', 2);
--Id = 5 Media_d = 3
INSERT INTO materials(media_id, format, quality, license_id)
  VALUES(3, 'giff', 'very low', 1);
--Id = 6 Media_d = 5
INSERT INTO materials(media_id, format, quality, license_id)
  VALUES(5, 'ogg', 'medium', 2);
--Id = 7 Media_d = 5
INSERT INTO materials(media_id, format, quality, license_id)
  VALUES(5, 'wav', 'high', 2);
--Id = 8 Media_d = 5
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(5, 'bmp', 'very high', 1);
--Id = 9 Media_d = 6
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(6, 'png', 'medium', 2);
--Id = 10 Media_d = 2
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(2, 'png', 'medium', 2);
--Id = 11 Media_d = 4
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(4, 'png', 'medium', 2);
--Id = 12 Media_d = 5
INSERT INTO materials(media_id, format, quality, license_id) 
  VALUES(5, 'mp4', 'medium', 1);