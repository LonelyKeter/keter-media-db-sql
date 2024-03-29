--Users
INSERT INTO users(login, password, email) 
VALUES
    ('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com'), --Id = 1
    ('Second author', decode('1782008c43f72ce64ea4a7f05e202b5f0356f69b079d584cf2952a3b8b37fa71', 'hex'), 'secondauthor@mail.com'), --Id = 2
    ('Third author', decode('d9f2fa7f824d1e0c4f7acfc95a9ce02ea844015d13548bf21b0ebb8cd4076e43', 'hex'), 'thirdauthor@mail.com'), --Id = 3,
    ('Fourth author', decode('cc6ca44341a31d8f742d773b7910f55fdfbc236c9819139c92e21e2bfa61f199', 'hex'), 'fourthauthor@mail.com'), --Id = 4

    ('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com'); --Id = 5

INSERT INTO users(login, password, email, administration_permissions)
VALUES
    ('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', 'moderator'), --Id = 6
    ('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', 'admin'), --Id = 7
    ('12345', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), '12345@mail.com', 'admin'); --Id = 8


insert into users (login, password, email) values ('Reidar Brisson', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rbrisson0@google.com.au');
insert into users (login, password, email) values ('Griffie Pering', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gpering1@nationalgeographic.com');
insert into users (login, password, email) values ('Dom Faragan', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dfaragan2@chicagotribune.com');
insert into users (login, password, email) values ('Jannel Poletto', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'jpoletto3@ox.ac.uk');
insert into users (login, password, email) values ('Emerson Wilflinger', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'ewilflinger4@macromedia.com');
insert into users (login, password, email) values ('Miguel Shaddick', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mshaddick5@hc360.com');
insert into users (login, password, email) values ('Ranee Issitt', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rissitt6@ocn.ne.jp');
insert into users (login, password, email) values ('Rourke Leinster', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rleinster7@netlog.com');
insert into users (login, password, email) values ('Bax Lante', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'blante8@flickr.com');
insert into users (login, password, email) values ('Ruttger Orring', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rorring9@moonfruit.com');
insert into users (login, password, email) values ('Grenville Dobie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gdobiea@shinystat.com');
insert into users (login, password, email) values ('Anselma Burkwood', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'aburkwoodb@over-blog.com');
insert into users (login, password, email) values ('Rickie Rooper', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rrooperc@chronoengine.com');
insert into users (login, password, email) values ('Huey Cockshut', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'hcockshutd@feedburner.com');
insert into users (login, password, email) values ('Donn O''Curneen', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'docurneene@bravesites.com');
insert into users (login, password, email) values ('Guillaume Nodes', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gnodesf@alexa.com');
insert into users (login, password, email) values ('Huntington Gayne', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'hgayneg@earthlink.net');
insert into users (login, password, email) values ('Bram Reiach', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'breiachh@intel.com');
insert into users (login, password, email) values ('Pail Farrall', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pfarralli@networkadvertising.org');
insert into users (login, password, email) values ('Pall Duckerin', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pduckerinj@vistaprint.com');
insert into users (login, password, email) values ('Arne Cabrales', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'acabralesk@cpanel.net');
insert into users (login, password, email) values ('Sheree Blanket', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sblanketl@tripod.com');
insert into users (login, password, email) values ('Sada Bucky', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sbuckym@php.net');
insert into users (login, password, email) values ('Sal Blakes', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sblakesn@a8.net');
insert into users (login, password, email) values ('Celestia Orys', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'coryso@yahoo.co.jp');
insert into users (login, password, email) values ('Patsy McLaughlan', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pmclaughlanp@soup.io');
insert into users (login, password, email) values ('Rosy Thorbon', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rthorbonq@ihg.com');
insert into users (login, password, email) values ('Fred Rosengart', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'frosengartr@yelp.com');
insert into users (login, password, email) values ('Raynard Chapling', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rchaplings@istockphoto.com');
insert into users (login, password, email) values ('Silvanus Cronkshaw', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'scronkshawt@squidoo.com');
insert into users (login, password, email) values ('Putnam MacRorie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pmacrorieu@economist.com');
insert into users (login, password, email) values ('Averil Rodda', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'aroddav@google.it');
insert into users (login, password, email) values ('Mag Sargerson', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'msargersonw@rambler.ru');
insert into users (login, password, email) values ('Deeyn Ortet', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dortetx@howstuffworks.com');
insert into users (login, password, email) values ('Dosi Gallie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dgalliey@comcast.net');
insert into users (login, password, email) values ('Patty Pfiffer', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'ppfifferz@go.com');
insert into users (login, password, email) values ('Gard Marshman', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gmarshman10@upenn.edu');
insert into users (login, password, email) values ('Renate Archambault', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rarchambault11@goodreads.com');
insert into users (login, password, email) values ('Bette Kobiera', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'bkobiera12@hao123.com');
insert into users (login, password, email) values ('Etheline Blasoni', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'eblasoni13@bravesites.com');
insert into users (login, password, email) values ('Verney Berard', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'vberard14@hao123.com');
insert into users (login, password, email) values ('Stanislaus Gosz', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sgosz15@drupal.org');
insert into users (login, password, email) values ('Paulie Dowsey', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pdowsey16@aboutads.info');
insert into users (login, password, email) values ('Cobb Gentil', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'cgentil17@businesswire.com');
insert into users (login, password, email) values ('Mareah Dashper', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mdashper18@gravatar.com');
insert into users (login, password, email) values ('Liz Van Der Vlies', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'lvan19@theglobeandmail.com');
insert into users (login, password, email) values ('Marris Midgely', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mmidgely1a@goo.gl');
insert into users (login, password, email) values ('Jackelyn Maguire', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'jmaguire1b@vk.com');
insert into users (login, password, email) values ('Oriana Senter', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'osenter1c@simplemachines.org');
insert into users (login, password, email) values ('Kathlin Hughman', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'khughman1d@google.pl');
