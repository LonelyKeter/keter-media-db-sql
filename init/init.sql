SET SCHEMA 'public'; 
--Countries
INSERT INTO Countries VALUES('UA', 'Ukraine');
INSERT INTO Countries VALUES('RU', 'Russia');
INSERT INTO Countries VALUES('BL', 'Belarus');
INSERT INTO Countries VALUES('IT', 'Italy');
INSERT INTO Countries VALUES('FR', 'France');
INSERT INTO Countries VALUES('GR', 'Germany');
INSERT INTO Countries VALUES('SP', 'Spain');
--Users
--Id = 1
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com', true, false, false);
--Id = 2
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Second author', decode('1782008c43f72ce64ea4a7f05e202b5f0356f69b079d584cf2952a3b8b37fa71', 'hex'), 'secondauthor@mail.com', true, false, false);
--Id = 3
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Third author', decode('d9f2fa7f824d1e0c4f7acfc95a9ce02ea844015d13548bf21b0ebb8cd4076e43', 'hex'), 'thirdauthor@mail.com', true, false, false);
--Id = 4
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Fourth author', decode('cc6ca44341a31d8f742d773b7910f55fdfbc236c9819139c92e21e2bfa61f199', 'hex'), 'fourthauthor@mail.com', true, false, false);


--Id = 5
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com', false, false, false);
--Id = 6
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', false, true, false);
--Id = 7
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', false, true, false); 
INSERT INTO Authors(Id, Country)
  VALUES(1, 'UA');
INSERT INTO Authors(Id, Country)
  VALUES(2, 'RU');
INSERT INTO Authors(Id, Country)
  VALUES(3, 'BL');
INSERT INTO Authors(Id, Country)
  VALUES(4, 'FR'); 
--Id = 1 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My first song', 1, 'Audio', '2020-11-11', 7);
--Id = 2 (Preview for id = 1) AuthorId = 1
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date, Rating) 
  VALUES(False, 'My first song. Preview', 1, 'Image', '2020-11-11', NULL);
--Id = 3  AuthorId = 2
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My first photo', 2, 'Image', '2020-11-19', 8);
--Id = 4 (Preview for id = 2) AuthorId = 2
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date, Rating) 
  VALUES(False, 'My first photo.Preview', 2, 'Image', '2020-11-19', NULL);
--Id = 5 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My second song', 1, 'Audio', '2020-12-01', 8);
--Id = 6 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Одесский дворик', 3, 'Image', '2020-12-12', 9);
--Id = 7 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Настоящая одесса', 3, 'Video', '2020-12-01', 7);
--Id = 8 AuthorId = 4
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Very unpopular video', 4, 'Video', '2021-01-02', 2);
 
--Licences
--Id = 1
INSERT INTO Licenses(Title, Text, Date, Relevance, Substitution) 
  VALUES(
  'FREE', 
  'You can do whatever you want and however you like', 
  '2020-01-01', 
  TRUE, 
  NULL);
--Id = 2
INSERT INTO Licenses(Title, Text, Date, Relevance, Substitution) 
  VALUES(
  'Creative Commons', 
  'You can do whatever you want and however you like, if you don''t make money', 
  '2020-01-01', 
  TRUE, 
  NULL);
 
--Materials
--Id = 1 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, '.wav', 'MEDIUM', 1);
--Id = 2 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, '.mp3', 'LOW', 1);
--Id = 3 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(3, '.bmp', 'HIGH', 2);
--Id = 4 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, '.jpg', 'MEDIUM', 2);
--Id = 5 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, '.giff', 'VERY LOW', 1);
--Id = 6 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, '.ogg', 'MEDIUM', 2);
--Id = 7 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, '.wav', 'HIGH', 2);
--Id = 8 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, '.bmp', 'VERY HIGH', 1);
--Id = 9 Media_d = 6
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(6, '.png', 'MEDIUM', 2);
--Id = 10 Media_d = 2
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(2, '.png', 'MEDIUM', 2);
--Id = 11 Media_d = 4
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(4, '.png', 'MEDIUM', 2);
--Id = 12 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, '.mp4', 'MEDIUM', 1);
 
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(1, 5, 'Not so bad', 6, '2020-12-08 07:07:07');
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(1, 6, 'Nice', 7, '2020-12-08 14:21:09');
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(5, 7, 'First one was better(', 6, '2021-01-02 04:05:06');
