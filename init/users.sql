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