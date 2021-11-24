SET SCHEMA 'public'; 
--Countries
INSERT INTO countries VALUES('ua', 'Ukraine');
INSERT INTO countries VALUES('ru', 'Russia');
INSERT INTO countries VALUES('bl', 'Belarus');
INSERT INTO countries VALUES('it', 'Italy');
INSERT INTO countries VALUES('fr', 'France');
INSERT INTO countries VALUES('gr', 'Germany');
INSERT INTO countries VALUES('sp', 'Spain');--Users
--Id = 1
INSERT INTO users(login, password, email) 
  VALUES('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com');
--Id = 2
INSERT INTO users(login, password, email) 
  VALUES('Second author', decode('1782008c43f72ce64ea4a7f05e202b5f0356f69b079d584cf2952a3b8b37fa71', 'hex'), 'secondauthor@mail.com');
--Id = 3
INSERT INTO users(login, password, email) 
  VALUES('Third author', decode('d9f2fa7f824d1e0c4f7acfc95a9ce02ea844015d13548bf21b0ebb8cd4076e43', 'hex'), 'thirdauthor@mail.com');
--Id = 4
INSERT INTO users(login, password, email) 
  VALUES('Fourth author', decode('cc6ca44341a31d8f742d773b7910f55fdfbc236c9819139c92e21e2bfa61f199', 'hex'), 'fourthauthor@mail.com');


--Id = 5
INSERT INTO users(login, password, email)
  VALUES('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com');
--Id = 6
INSERT INTO users(login, password, email, administration_permissions)
  VALUES('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', 'moderator');
--Id = 7
INSERT INTO users(login, password, email, administration_permissions) 
  VALUES('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', 'admin');
--Id = 8
INSERT INTO users(login, password, email, administration_permissions) 
  VALUES('12345', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), '12345@mail.com', 'admin');
 
INSERT INTO authors(id, country)
  VALUES(1, 'ua');
INSERT INTO authors(id, country)
  VALUES(2, 'ru');
INSERT INTO authors(id, country)
  VALUES(3, 'bl');
INSERT INTO authors(id, country)
  VALUES(4, 'fr'); 
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

 

--Licences
--Id = 1
INSERT INTO licenses(title, text, date, relevance, substitution) 
  VALUES(
  'FREE', 
  'You can do whatever you want and however you like', 
  '2020-01-01', 
  TRUE, 
  NULL);
--Id = 2
INSERT INTO licenses(title, text, date, relevance, substitution) 
  VALUES(
  'Creative Commons', 
  'You can do whatever you want and however you like, if you don''t make money', 
  '2020-01-01', 
  TRUE, 
  NULL); 
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
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(1, 5, 'Not so bad', '2020-12-08 07:07:07');
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(1, 6, 'Nice', '2020-12-08 14:21:09');
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(5, 7, 'First one was better(', '2021-01-02 04:05:06');
 
--Material usages
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(1, 1, '2020-11-15', 1, 6);
INSERT INTO material_usage(material_id, user_id, date, license_id) 
  VALUES(2, 2, '2020-11-17', 1);
INSERT INTO material_usage(material_id, user_id, date, license_id) 
  VALUES(2, 3, '2020-11-19', 1);
INSERT INTO material_usage(material_id, user_id, date, license_id) 
  VALUES(3, 4, '2020-12-02', 2);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(5, 1, '2020-12-03', 1, 4);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(7, 4, '2020-12-03', 2, 5);
INSERT INTO material_usage(material_id, user_id, date, license_id) 
  VALUES(6, 3, '2020-12-03', 2);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(6, 4, '2020-12-04', 2, 7);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(4, 3, '2020-12-04', 2, 5);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(8, 1, '2020-12-08', 1, 5);
INSERT INTO material_usage(material_id, user_id, date, license_id) 
  VALUES(1, 3, '2020-12-09', 1);
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
  VALUES(5, 4, '2020-12-09', 1, 1); 
SELECT update.update_ratings();
SELECT update.update_use_count();