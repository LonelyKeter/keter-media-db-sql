--Materials
--Id = 1 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, 'wav', 'MEDIUM', 1);
--Id = 2 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, 'mp3', 'LOW', 1);
--Id = 3 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(3, 'bmp', 'HIGH', 2);
--Id = 4 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, 'jpg', 'MEDIUM', 2);
--Id = 5 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, 'giff', 'VERY LOW', 1);
--Id = 6 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, 'ogg', 'MEDIUM', 2);
--Id = 7 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, 'wav', 'HIGH', 2);
--Id = 8 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, 'bmp', 'VERY HIGH', 1);
--Id = 9 Media_d = 6
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(6, 'png', 'MEDIUM', 2);
--Id = 10 Media_d = 2
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(2, 'png', 'MEDIUM', 2);
--Id = 11 Media_d = 4
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(4, 'png', 'MEDIUM', 2);
--Id = 12 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, 'mp4', 'MEDIUM', 1);