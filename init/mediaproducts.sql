--Id = 1 AuthorId = 1
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('My first song', 1, 'audio', '2020-11-11');
--Id = 2 (Preview for id = 1) AuthorId = 1
INSERT INTO mediaproducts(public, title, author_id, kind, date) 
  VALUES(False, 'My first song. Preview', 1, 'image', '2020-11-11');
--Id = 3  AuthorId = 2
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('My first photo', 2, 'image', '2020-11-19');
--Id = 4 (Preview for id = 2) AuthorId = 2
INSERT INTO mediaproducts(public, title, author_id, kind, date) 
  VALUES(False, 'My first photo.Preview', 2, 'image', '2020-11-19');
--Id = 5 AuthorId = 1
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('My second song', 1, 'audio', '2020-12-01');
--Id = 6 AuthorId = 3
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('Одесский дворик', 3, 'image', '2020-12-12');
--Id = 7 AuthorId = 3
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('Настоящая одесса', 3, 'video', '2020-12-01');
--Id = 8 AuthorId = 4
INSERT INTO mediaproducts(title, author_id, kind, date) 
  VALUES('Very unpopular video', 4, 'video', '2021-01-02');

