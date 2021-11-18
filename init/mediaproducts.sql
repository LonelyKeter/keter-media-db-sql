--Id = 1 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My first song', 1, 'Audio', '2020-11-11');
--Id = 2 (Preview for id = 1) AuthorId = 1
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date) 
  VALUES(False, 'My first song. Preview', 1, 'Image', '2020-11-11');
--Id = 3  AuthorId = 2
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My first photo', 2, 'Image', '2020-11-19');
--Id = 4 (Preview for id = 2) AuthorId = 2
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date) 
  VALUES(False, 'My first photo.Preview', 2, 'Image', '2020-11-19');
--Id = 5 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My second song', 1, 'Audio', '2020-12-01');
--Id = 6 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Одесский дворик', 3, 'Image', '2020-12-12');
--Id = 7 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Настоящая одесса', 3, 'Video', '2020-12-01');
--Id = 8 AuthorId = 4
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Very unpopular video', 4, 'Video', '2021-01-02');

