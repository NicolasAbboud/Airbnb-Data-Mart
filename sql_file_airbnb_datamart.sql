--------------------------------------------------
-- Airbnb Datamart Initialization Script
-- Purpose: Reset schema by dropping existing tables in dependency-safe order
--------------------------------------------------

-- Select target database for operations
USE airbnb_datamart;

-- Temporarily disable foreign key checks to allow unrestricted table deletion
SET FOREIGN_KEY_CHECKS = 0;

--------------------------------------------------
-- Clean Slate: Drop all existing tables if present
-- Note: Table order respects foreign key dependencies to prevent drop errors
--------------------------------------------------

DROP TABLE IF EXISTS guestSocialNetwork, socialNetwork, notification, review, customerService, reservation, 
    transaction, booking, room, vacationRentalPolicy, cancellationPolicy, vacationRentalAmenity, amenity, 
    vacationRental, location, city, loginHistory, travelAdmin, host, guest, event, promotion;

-- Re-enable foreign key checks to restore integrity enforcement
SET FOREIGN_KEY_CHECKS = 1;

--------------------------------------------------
-- Guest-Related Entities
-- Purpose: Define core user roles and relationships within the platform
--------------------------------------------------

-- guest table stores personal details of users who can book properties
CREATE TABLE guest (
    guestID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    phoneNumber VARCHAR(25),
    profilePicture VARCHAR(255),
    -- address-related details added for more comprehensive guest info
    street VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255),
    country VARCHAR(255),
    gdprAcknowledgement BOOLEAN,
    languageSettings VARCHAR(255)
);

-- host table stores details about property owners. Guests can also be hosts.
CREATE TABLE Host (
    hostID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    rating FLOAT,
    verified BOOLEAN,
    hostSince DATE,
    stars INT,
    externalReviews TEXT,
    referredByHostID INT NULL,
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID) ON DELETE CASCADE, -- Cascade deletes to remove related hosts
    FOREIGN KEY (referredByHostID) REFERENCES host(hostID) ON DELETE SET NULL -- Prevent circular references. Self-referencing (recursive) relationship
);

-- travelAdmin table stores system admins who can manage bookings and policies
CREATE TABLE travelAdmin (
    adminID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phoneNumber VARCHAR(25),
    guestID INT NOT NULL,
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID)
);

--------------------------------------------------
-- Social Integration & Guest Login Tracking
-- Purpose: Enable social media linking and monitor guest login activity
--------------------------------------------------

-- socialNetwork table stores social media networks that guests can link to
CREATE TABLE socialNetwork (
    networkID INT AUTO_INCREMENT PRIMARY KEY,
    networkName VARCHAR(255),
    url VARCHAR(255)
);

-- guestSocialNetwork table links guests to their social media profiles
CREATE TABLE guestSocialNetwork (
    guestSocialNetworkID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    networkID INT NOT NULL,
    profileURL VARCHAR(255),
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID),
    FOREIGN KEY (networkID) REFERENCES socialNetwork(networkID)
);

-- loginHistory logs guest login details for security purposes
CREATE TABLE loginHistory (
    loginID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    loginTimestamp DATETIME,
    ipAddress VARCHAR(255),
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID)
);

--------------------------------------------------
-- notification: Stores system-generated alerts and messages for guests
-- Purpose: Centralized logging of platform communications (e.g. booking updates, policy changes, promotions)
-- Scope: Tied to individual guests via foreign key; supports audit trails and multilingual messaging
--------------------------------------------------
CREATE TABLE notification (
    notificationID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    content TEXT,
    timestamp DATETIME,
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID)
);

--------------------------------------------------
-- Location & Rental-related Tables
-- Purpose: Define hierarchical location data and associate it with rental listings
-- Scope: Enables geospatial filtering, multilingual targeting, and host-property mapping
--------------------------------------------------

-- city table stores city details, referenced by properties
CREATE TABLE city (
    cityID INT AUTO_INCREMENT PRIMARY KEY,
    cityName VARCHAR(255),
    country VARCHAR(255)
);

-- location table links specific addresses to cities
CREATE TABLE location (
    locationID INT AUTO_INCREMENT PRIMARY KEY,
    cityID INT,
    country VARCHAR(255),
    partOfCity VARCHAR(255),
    address VARCHAR(255),
    phoneNumber VARCHAR(25),
    email VARCHAR(255),
    
    FOREIGN KEY (cityID) REFERENCES city(cityID)
);

-- vacationRental table stores rental property details
CREATE TABLE vacationRental (
    vacationRentalID INT AUTO_INCREMENT PRIMARY KEY,
    hostID INT NOT NULL,
    locationID INT NOT NULL,
    propertyType VARCHAR(255),
    description TEXT,
    maxGuests INT,
    ratePerPerson FLOAT,
    ownBathroom BOOLEAN,
    petFriendly BOOLEAN,
    freeParking BOOLEAN,
    numberOfBeds INT,
    calendarAvailability TEXT,
    proximityToBeach VARCHAR(255),
    proximityToShops VARCHAR(255),
    proximityToSightSeeing VARCHAR(255),
    
    FOREIGN KEY (hostID) REFERENCES host(hostID) ON DELETE CASCADE, 
    FOREIGN KEY (locationID) REFERENCES location(locationID) ON DELETE CASCADE
);

--------------------------------------------------
-- Room, Amenity, and Policy related tables
-- Purpose: Define rental-specific configurations including room-level pricing, available amenities, and cancellation rules
-- Scope: Supports granular booking logic, guest filtering, and host-defined policies
--------------------------------------------------

-- room table links specific rooms to rentals with availability and pricing
CREATE TABLE room (
    roomID INT AUTO_INCREMENT PRIMARY KEY,
    vacationRentalID INT NOT NULL,
    roomType VARCHAR(255),
    pricePerNight FLOAT,
    availableFrom DATE,
    availableTo DATE,
    
    FOREIGN KEY (vacationRentalID) REFERENCES vacationRental(vacationRentalID)
);

-- amenity table stores general amenities like Wi-Fi, parking, etc.
CREATE TABLE amenity (
    amenityID INT AUTO_INCREMENT PRIMARY KEY,
    amenityName VARCHAR(255),
    description TEXT
);

-- Linking amenities to vacation rentals
CREATE TABLE vacationRentalAmenity (
    vacationRentalID INT NOT NULL,
    amenityID INT NOT NULL,
    PRIMARY KEY (vacationRentalID, amenityID),
    
    FOREIGN KEY (vacationRentalID) REFERENCES vacationRental(vacationRentalID),
    FOREIGN KEY (amenityID) REFERENCES amenity(amenityID)
);

-- Cancellation policies for rentals
CREATE TABLE cancellationPolicy (
    policyID INT AUTO_INCREMENT PRIMARY KEY,
    policyName VARCHAR(255),
    description TEXT
);

-- Linking cancellation policies to rentals
CREATE TABLE vacationRentalPolicy (
    vacationRentalID INT NOT NULL,
    policyID INT NOT NULL,
    PRIMARY KEY (vacationRentalID, policyID),
    
    FOREIGN KEY (vacationRentalID) REFERENCES vacationRental(vacationRentalID),
    FOREIGN KEY (policyID) REFERENCES cancellationPolicy(policyID)
);

--------------------------------------------------
-- Booking Table
-- Purpose: Capture transactional details of guest reservations, including pricing, status, cancellation terms, and event metadata
-- Scope: Central table linking guests, rooms, and optional event-based bookings
--------------------------------------------------

CREATE TABLE booking (
    bookingID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    roomID INT NOT NULL,
    bookingDate DATETIME NOT NULL,
    checkInDate DATE NOT NULL,
    checkOutDate DATE NOT NULL,
    totalPrice FLOAT NOT NULL,
    paymentStatus ENUM('Paid', 'Pending', 'Cancelled') NOT NULL,
    lengthOfStay INT NOT NULL,
    cancellationDeadline DATE,
    cancellationRefund FLOAT,
    dateOfCancellation DATE,
    hostPayout FLOAT, 
    eventName VARCHAR(255),
    startDate DATE,
    endDate DATE,
    description TEXT,
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID) ON DELETE CASCADE,
    FOREIGN KEY (roomID) REFERENCES room(roomID) ON DELETE CASCADE
);

--------------------------------------------------
-- Financial Transactions, Booking Reservations, and Guest/Host Reviews Tables
-- Purpose: Capture payment flows, reservation metadata, and post-stay feedback
-- Scope: Supports audit trails, policy enforcement, and platform reputation systems
--------------------------------------------------

-- Storing transactions for payments and refunds
CREATE TABLE transaction (
    transactionID INT AUTO_INCREMENT PRIMARY KEY,
    guestID INT NOT NULL,
    bookingID INT NOT NULL,
    amount FLOAT NOT NULL,
    transactionDate DATETIME NOT NULL,
    paymentMethod ENUM('CreditCard', 'BankTransfer', 'Cash', 'Voucher', 'PayPal', 'ApplePay', 'GPay', 'CreditCard_MasterCard', 'CreditCard_Visa', 
    'CreditCard_AMEX', 'CreditCard_FirstCard', 'CreditCard_DinersClub', 'Maestro', 'SOFORT_Payment', 'BNPL', 'Klarna') NOT NULL,
    transactionType ENUM('Payment', 'Refund') NOT NULL,  
    refundProcessedDate DATETIME NULL,  
    description TEXT NOT NULL,  
    
    FOREIGN KEY (guestID) REFERENCES guest(guestID),
    FOREIGN KEY (bookingID) REFERENCES booking(bookingID)
);

-- reservation table storing additional booking details and policies
CREATE TABLE reservation (
    reservationID INT AUTO_INCREMENT PRIMARY KEY,
    bookingID INT NOT NULL,
    adminID INT NOT NULL,
    dateOfReservation DATE,
    paymentStatus ENUM('Paid', 'Pending', 'Cancelled'),
    lengthOfStay INT,
    cancellationPolicy TEXT,
    refundPolicy TEXT,
    
    FOREIGN KEY (bookingID) REFERENCES booking(bookingID),
    FOREIGN KEY (adminID) REFERENCES travelAdmin(adminID)
);

-- review table for collecting feedback from guests or hosts
CREATE TABLE review (
    reviewID INT AUTO_INCREMENT PRIMARY KEY,
    bookingID INT NOT NULL,
    reviewerID INT NOT NULL,  
    reviewerType ENUM('Guest', 'Host') NOT NULL,  
    rating INT,
    comment TEXT,
    reviewDate DATE,
    
    FOREIGN KEY (bookingID) REFERENCES booking(bookingID) ON DELETE CASCADE,
    FOREIGN KEY (reviewerID) REFERENCES guest(guestID) ON DELETE CASCADE
);

--------------------------------------------------
-- Customer Support & Event Metadata Tables
-- Purpose: Manage booking-related support tickets and associate local events with guest stays
-- Scope: Enables resolution tracking, guest engagement, and contextual enrichment of bookings
--------------------------------------------------

-- customer service table for managing support tickets related to bookings
CREATE TABLE customerService (
    customerServiceID INT AUTO_INCREMENT PRIMARY KEY,
    bookingID INT NOT NULL,
    issueDescription TEXT,
    resolution TEXT,
    contactMethod VARCHAR(255),
    resolutionDate DATE,
    
    FOREIGN KEY (bookingID) REFERENCES booking(bookingID)
);

-- event table to link events to bookings, such as local activities
CREATE TABLE event (
    eventID INT AUTO_INCREMENT PRIMARY KEY,
    bookingID INT NOT NULL,
    eventName VARCHAR(255),
    startDate DATE,
    endDate DATE,
    description TEXT,
    
    FOREIGN KEY (bookingID) REFERENCES booking(bookingID)
);

--------------------------------------------------
-- promotion: Defines rental-specific discount campaigns
-- Purpose: Enable hosts to offer time-bound discounts on vacation rentals
-- Scope: Supports seasonal pricing, marketing strategies, and guest incentives
--------------------------------------------------
CREATE TABLE promotion (
    promotionID INT AUTO_INCREMENT PRIMARY KEY,
    vacationRentalID INT NOT NULL,
    discountPercentage FLOAT,
    startDate DATE,
    endDate DATE,
    
    FOREIGN KEY (vacationRentalID) REFERENCES vacationRental(vacationRentalID)
);

--------------------------------------------------
-- Insert test data into the guest table
-- Guest data should cover various use cases such as international guests, language preferences, etc.
--------------------------------------------------
INSERT INTO guest (name, email, password, phoneNumber, profilePicture, street, city, state, country, gdprAcknowledgement, languageSettings)
VALUES 
    ('Jack Haddad', 'jack.haddad@example.com', 'passForJack', '96171234567', 'jack_profile.jpg', 'Hamra Street', 'Beirut', '', 'Lebanon', TRUE, 'French'),
    ('Ivana Horvat', 'ivana.horvat@example.hr', 'passForIvana', '385912345678', 'ivana_profile.jpg', 'Ulica Kralja Zvonimira 456', 'Zagreb', '', 'Croatia', TRUE, 'Croatian'),
    ('Lukas Schneider', 'lukas.schneider@example.de', 'passForLukas', '4917612345678', 'lukas_profile.jpg', 'Eichenstraße 789', 'Berlin', '', 'Germany', TRUE, 'German'),
    ('Giovanni Rossi', 'giovanni.rossi@example.it', 'passForGiovanni', '390123456789', 'giovanni_profile.jpg', '101 Maple St', 'Rome', '', 'Italy', TRUE, 'Italian'),
    ('Florian Berger', 'florian.berger@example.at', 'passForFlorian', '436641234567', 'florian_profile.jpg', 'Piniengasse 202', 'Wien', '', 'Austria', TRUE, 'German'),
    ('Sakura Tanaka', 'sakura.tanaka@example.jp', 'passForSakura', '819012345678', 'sakura_profile.jpg', '303 Birch St', 'Tokyo', '', 'Japan', TRUE, 'Japanese'),
    ('Aino Virtanen', 'aino.virtanen@example.fi', 'passForAino', '358401234567', 'aino_profile.jpg', 'Setritie 404', 'Helsinki', '', 'Finland', TRUE, 'Finnish'),
    ('Thomas De Smedt', 'thomas.desmedt@example.be', 'passForThomas', '32475123456', 'thomas_profile.jpg', 'Dennenstraat 505', 'Brussels', '', 'Belgium', TRUE, 'Dutch'),
    ('Rahul Mehra', 'rahul.mehra@example.in', 'passForRahul', '919812345678', 'rahul_profile.jpg', '606 Maple Street', 'Mumbai', '', 'India', TRUE, 'Hindi'),
    ('Julien Moreau', 'julien.moreau@example.fr', 'passForJulien', '33612345678', 'julien_profile.jpg', '707 Rue du Chêne', 'Lyon', '', 'France', TRUE, 'French'),
    ('Youssef Benhaddou', 'youssef.benhaddou@example.ma', 'passForYoussef', '212612345678', 'youssef_profile.jpg', '808 Rue du Cèdre', 'Casablanca', '', 'Morocco', TRUE, 'Arabic'),
    ('Liam Taylor', 'liam.taylor@example.co.uk', 'passForLiam', '447712345678', 'liam_profile.jpg', '909 Birch Street', 'Manchester', '', 'United Kingdom', TRUE, 'English (UK)'),
    ('Olivia Brown', 'olivia.brown@example.au', 'passForOlivia', '611234567890', 'olivia_profile.jpg', '1010 Cedar St', 'Sydney', 'New South Wales', 'Australia', TRUE, 'English (Australia)'),
    ('Michael Johnson', 'michael.johnson@example.us', 'passForMichael', '11234567890', 'michael_profile.jpg', '1111 Maple St', 'New York', 'NY', 'USA', TRUE, 'English (USA)'),
    ('Sophie Chen', 'sophie.chen@example.ca', 'passForSophie', '16041234567', 'sophie_profile.jpg', '1212 Oak Street', 'Vancouver', 'British Columbia', 'Canada', TRUE, 'English (Canada)'),
    ('Sanne de Vries', 'sanne.devries@example.nl', 'passForSanne', '31612345678', 'sanne_profile.jpg', 'Dennenhoutstraat 1313', 'Amsterdam', '', 'Netherlands', TRUE, 'Dutch'),
    ('Carlos Martínez', 'carlos.martinez@example.es', 'passForCarlos', '34661234567', 'carlos_profile.jpg', 'Calle del Cedro 1414', 'Madrid', '', 'Spain', TRUE, 'Spanish'),
    ('Sophie Schmidt', 'sophie.schmidt@example.de', 'passForSophie', '491523456789', 'sophie_profile.jpg', '1515 Maple St', 'Hamburg', '', 'Germany', TRUE, 'German'),
    ('Mateo Fernández', 'mateo.fernandez@example.com.ar', 'passForMateo', '5491123456789', 'mateo_profile.jpg', 'Calle del Roble 1616', 'Buenos Aires', '', 'Argentina', TRUE, 'Spanish'),
    ('Zsófia Kovács', 'zsofia.kovacs@example.hu', 'passForZsofia', '36201234567', 'zsofia_profile.jpg', 'Fenyő utca 1717', 'Budapest', '', 'Hungary', TRUE, 'Hungarian');


--------------------------------------------------
-- Insert test data into the host table
-- This links hosts to guests, making some guests also hosts
--------------------------------------------------
INSERT INTO host (guestID, rating, verified, hostSince, stars, externalReviews, referredByHostID)
VALUES 
    (1, 4.5, TRUE, '2024-01-01', 5, 'Great reviews from external sites.', NULL),   
    (2, 4.0, TRUE, '2025-03-15', 4, 'Positive feedback from external platforms.', NULL),   
    (3, 4.8, TRUE, '2023-11-20', 5, 'Outstanding reviews.', NULL),   
    (4, 4.2, TRUE, '2024-06-25', 4, 'Excellent ratings on various platforms.', NULL),   
    (5, 4.7, TRUE, '2025-07-10', 5, 'Highly recommended by guests.', NULL),   
    (6, 4.9, TRUE, '2025-05-22', 5, 'Top-rated host with many positive reviews.', NULL),   
    (7, 4.3, TRUE, '2023-12-05', 4, 'Good reviews overall.', NULL),   
    (8, 4.6, TRUE, '2024-02-15', 5, 'Consistent positive feedback from guests.', NULL),   
    (9, 4.1, TRUE, '2025-09-01', 4, 'Mixed reviews but generally positive.', NULL),   
    (10, 4.4, TRUE, '2025-08-18', 5, 'Great experience reported by guests.', NULL),  
    (11, 4.3, TRUE, '2024-10-10', 4, 'Strong feedback from external reviews.', NULL),  
    (12, 4.8, TRUE, '2025-01-01', 5, 'Highly recommended by several sources.', NULL),  
    (13, 4.7, TRUE, '2024-03-20', 5, 'Great host with excellent reviews.', NULL),  
    (14, 4.9, TRUE, '2023-07-07', 5, 'One of the top-rated hosts.', NULL),  
    (15, 4.5, TRUE, '2025-04-15', 5, 'Guests consistently leave positive feedback.', NULL),  
    (16, 4.6, TRUE, '2023-09-25', 5, 'Highly rated by multiple sources.', NULL),  
    (17, 4.2, TRUE, '2024-11-10', 4, 'Reviews indicate a good experience.', NULL),  
    (18, 4.5, TRUE, '2025-02-22', 5, 'Popular host with lots of positive reviews.', NULL),  
    (19, 4.7, TRUE, '2024-12-15', 5, 'Guests frequently recommend this host.', NULL),  
    (20, 4.4, TRUE, '2025-03-10', 4, 'Well-reviewed host with solid ratings.', NULL);  

--------------------------------------------------
-- Insert test data into the socialNetwork table
-- Define different social media platforms
--------------------------------------------------
INSERT INTO socialNetwork (networkName, url)
VALUES 
    ('Facebook', 'https://www.facebook.com'),
    ('Twitter', 'https://www.twitter.com'),
    ('Instagram', 'https://www.instagram.com'),
    ('LinkedIn', 'https://www.linkedin.com'),
    ('WhatsApp', 'https://www.whatsapp.com'),
    ('WeChat', 'https://www.wechat.com'),
    ('VK', 'https://www.vk.com'),
    ('Snapchat', 'https://www.snapchat.com'),
    ('TikTok', 'https://www.tiktok.com'),
    ('Pinterest', 'https://www.pinterest.com'),
    ('Reddit', 'https://www.reddit.com'),
    ('Tumblr', 'https://www.tumblr.com'),
    ('Flickr', 'https://www.flickr.com'),
    ('YouTube', 'https://www.youtube.com'),
    ('Vimeo', 'https://www.vimeo.com'),
    ('Discord', 'https://www.discord.com'),
    ('Telegram', 'https://www.telegram.org'),
    ('Signal', 'https://www.signal.org'),
    ('Baidu Tieba', 'https://tieba.baidu.com'),
    ('Douban', 'https://www.douban.com');
    
--------------------------------------------------
-- Insert test data into the guestSocialNetwork table
-- Social media profiles linked to guests
--------------------------------------------------
INSERT INTO guestSocialNetwork (guestID, networkID, profileURL)
VALUES 
    (1, 1, 'https://www.facebook.com/jack.haddad'),
    (2, 2, 'https://www.twitter.com/ivana.horvat'),
    (3, 3, 'https://www.instagram.com/lukas.schneider'),
    (4, 4, 'https://www.linkedin.com/in/giovanni.rossi'),
    (5, 5, 'https://www.whatsapp.com/florian.berger'),
    (6, 6, 'https://www.wechat.com/sakura.tanaka'),
    (7, 7, 'https://www.vk.com/aino_virtanen'),
    (8, 8, 'https://www.snapchat.com/thomas.desmedt'),
    (9, 9, 'https://www.tiktok.com/rahul.mehra'),
    (10, 10, 'https://www.pinterest.com/julien.moreau'),
    (11, 11, 'https://www.reddit.com/user/youssef.benhaddou'),
    (12, 12, 'https://www.tumblr.com/liam.taylor'),
    (13, 13, 'https://www.flickr.com/olivia.brown'),
    (14, 14, 'https://www.youtube.com/michael.johnson'),
    (15, 15, 'https://www.vimeo.com/sophie.chen'),
    (16, 16, 'https://www.discord.com/sanne.devries'),
    (17, 17, 'https://www.telegram.org/carlos.martinez'),
    (18, 18, 'https://www.signal.org/sophie.schmidt'),
    (19, 19, 'https://tieba.baidu.com/mateo.fernandez'),
    (20, 20, 'https://www.douban.com/zsofia_kovacs');

--------------------------------------------------
-- Insert test data into the notification table
-- Notifications sent to guests
--------------------------------------------------
INSERT INTO notification (guestID, content, timestamp)
VALUES 
    (1, 'Welcome to our service!', '2024-09-01 08:10:00'),
    (2, 'Your booking has been confirmed.', '2024-09-01 09:15:00'),
    (3, 'Payment successful.', '2024-09-01 10:20:00'),
    (4, 'Your stay in Rome is coming up.', '2024-09-01 11:25:00'),
    (5, 'Check-in available for your booking.', '2024-09-01 12:30:00'),
    (6, 'Reminder: Leave a review for your recent stay.', '2024-09-01 13:35:00'),
    (7, 'New message from your host.', '2024-09-01 14:40:00'),
    (8, 'Special offer for your next stay.', '2024-09-01 15:45:00'),
    (9, 'Booking cancellation successful.', '2024-09-01 16:50:00'),
    (10, 'Your refund has been processed.', '2024-09-01 17:55:00'),
    (11, 'New property added in your favorite city.', '2024-09-01 18:00:00'),
    (12, 'Update your profile to get better recommendations.', '2024-09-01 19:05:00'),
    (13, 'New loyalty points added to your account.', '2024-09-01 20:10:00'),
    (14, 'Last chance to book your dream vacation.', '2024-09-01 21:15:00'),
    (15, 'Your stay in New York is coming up.', '2024-09-01 22:20:00'),
    (16, 'Your booking for Zurich has been confirmed.', '2024-09-01 23:25:00'),
    (17, 'Check-out reminder for your stay.', '2024-09-02 00:30:00'),
    (18, 'Thank you for staying with us!', '2024-09-02 01:35:00'),
    (19, 'Special promotion: 20% off your next booking.', '2024-09-02 02:40:00'),
    (20, 'Your profile has been updated successfully.', '2024-09-02 03:45:00');

--------------------------------------------------
-- Insert test data into the loginHistory table
-- Track guest login activity with timestamps and IP addresses
--------------------------------------------------
INSERT INTO loginHistory (guestID, loginTimestamp, ipAddress)
VALUES 
    (1, '2024-09-01 08:00:00', '192.168.1.1'),
    (2, '2024-09-01 09:00:00', '192.168.1.2'),
    (3, '2024-09-01 10:00:00', '192.168.1.3'),
    (4, '2024-09-01 11:00:00', '192.168.1.4'),
    (5, '2024-09-01 12:00:00', '192.168.1.5'),
    (6, '2024-09-01 13:00:00', '192.168.1.6'),
    (7, '2024-09-01 14:00:00', '192.168.1.7'),
    (8, '2024-09-01 15:00:00', '192.168.1.8'),
    (9, '2024-09-01 16:00:00', '192.168.1.9'),
    (10, '2024-09-01 17:00:00', '192.168.1.10'),
    (11, '2024-09-01 18:00:00', '192.168.1.11'),
    (12, '2024-09-01 19:00:00', '192.168.1.12'),
    (13, '2024-09-01 20:00:00', '192.168.1.13'),
    (14, '2024-09-01 21:00:00', '192.168.1.14'),
    (15, '2024-09-01 22:00:00', '192.168.1.15'),
    (16, '2024-09-01 23:00:00', '192.168.1.16'),
    (17, '2024-09-02 00:00:00', '192.168.1.17'),
    (18, '2024-09-02 01:00:00', '192.168.1.18'),
    (19, '2024-09-02 02:00:00', '192.168.1.19'),
    (20, '2024-09-02 03:00:00', '192.168.1.20');

--------------------------------------------------
-- Insert test data into the city table
-- Define cities and their corresponding countries
--------------------------------------------------
INSERT INTO city (cityName, country)
VALUES 
    ('Beirut', 'Lebanon'),
    ('Zagreb', 'Croatia'),
    ('Berlin', 'Germany'),
    ('Rome', 'Italy'),
    ('Wien', 'Austria'),
    ('Tokyo', 'Japan'),
    ('Helsinki', 'Finland'),
    ('Brussels', 'Belgium'),
    ('Mumbai', 'India'),
    ('Lyon', 'France'),
    ('Casablanca', 'Morocco'),
    ('Manchester', 'United Kingdom'),
    ('Sydney', 'Australia'),
    ('New York', 'USA'),
    ('Vancouver', 'Canada'),
    ('Amsterdam', 'Netherlands'),
    ('Madrid', 'Spain'),
    ('Hamburg', 'Germany'),
    ('Buenos Aires', 'Argentina'),
    ('Budapest', 'Hungary');

--------------------------------------------------
-- Insert test data into the location table
-- Specify addresses and locations for vacation rentals within cities
--------------------------------------------------
INSERT INTO location (cityID, country, partOfCity, address, phoneNumber, email)
VALUES 
    (1, 'Lebanon', 'Hamra', 'Hamra Street, Beirut', '96171234567', 'info@beirut.lb'),
    (2, 'Croatia', 'Donjigrad', 'Ulica Kralja Zvonimira 456, Zagreb', '385912345678', 'info@zagreb.hr'),
    (3, 'Germany', 'Mitte', 'Eichenstraße 789, Berlin', '4917612345678', 'info@berlin.de'),
    (4, 'Italy', 'Centrostorico', '101 Maple St, Rome', '390123456789', 'info@rome.it'),
    (5, 'Austria', 'Innerestadt', 'Piniengasse 202, Wien', '436641234567', 'info@wien.at'),
    (6, 'Japan', 'Shinjuku', '303 Birch St, Tokyo', '819012345678', 'info@tokyo.jp'),
    (7, 'Finland', 'Kallio', 'Setritie 404, Helsinki', '358401234567', 'info@helsinki.fi'),
    (8, 'Belgium', 'Ixelles', 'Dennenstraat 505, Brussels', '32475123456', 'info@brussels.be'),
    (9, 'India', 'Andheriwest', '606 Maple Street, Mumbai', '919812345678', 'info@mumbai.in'),
    (10, 'France', 'Presquile', '707 Rue du Chêne, Lyon', '33612345678', 'info@lyon.fr'),
    (11, 'Morocco', 'Maarif', '808 Rue du Cèdre, Casablanca', '212612345678', 'info@casablanca.ma'),
    (12, 'United Kingdom', 'Chorlton', '909 Birch Street, Manchester', '447712345678', 'info@manchester.uk'),
    (13, 'Australia', 'NSW', '1010 Cedar St, Sydney', '611234567890', 'info@sydney.au'),
    (14, 'USA', 'Manhattan', '1111 Maple St, New York, NY', '11234567890', 'info@newyork.us'),
    (15, 'Canada', 'Downtown', '1212 Oak Street, Vancouver, BC', '16041234567', 'info@vancouver.ca'),
    (16, 'Netherlands', 'Centrum', 'Dennenhoutstraat 1313, Amsterdam', '31612345678', 'info@amsterdam.nl'),
    (17, 'Spain', 'Salamanca', 'Calle del Cedro 1414, Madrid', '34661234567', 'info@madrid.es'),
    (18, 'Germany', 'Altona', '1515 Maple St, Hamburg', '491523456789', 'info@hamburg.de'),
    (19, 'Argentina', 'Palermo', 'Calle del Roble 1616, Buenos Aires', '5491123456789', 'info@buenosaires.ar'),
    (20, 'Hungary', 'Terezvaros', 'Fenyő utca 1717, Budapest', '36201234567', 'info@budapest.hu');

--------------------------------------------------
-- Insert test data into the vacationRental table
-- Define vacation rentals with relevant details like host, location, and property features
--------------------------------------------------
INSERT INTO vacationRental (
    hostID, locationID, propertyType, description, maxGuests, ratePerPerson, ownBathroom, 
    petFriendly, freeParking, numberOfBeds, calendarAvailability, proximityToBeach, 
    proximityToShops, proximityToSightSeeing)
VALUES
(1, 1, 'Apartment', 'Beautiful luxury apartment in the city center.', 4, 120.00, 1, 1, 1, 2, 'Available', '500m', '200m', '300m'),
(2, 2, 'House', 'Spacious family house with a garden.', 6, 150.00, 1, 1, 1, 3, 'Available', '1km', '500m', '700m'),
(3, 3, 'Apartment', 'Cozy apartment near the river.', 2, 80.00, 1, 0, 1, 1, 'Available', '300m', '100m', '200m'),
(4, 4, 'Villa', 'Luxury villa with ocean views.', 8, 250.00, 1, 1, 1, 4, 'Available', '50m', '1km', '500m'),
(5, 5, 'Condo', 'Modern condo in a high-rise building.', 3, 90.00, 1, 0, 1, 1, 'Available', '800m', '200m', '400m'),
(6, 6, 'Cottage', 'Charming cottage in the countryside.', 5, 130.00, 1, 1, 1, 2, 'Available', '10km', '5km', '6km'),
(7, 7, 'Townhouse', 'Stylish townhouse in a vibrant neighborhood.', 4, 140.00, 1, 1, 1, 2, 'Available', '1km', '500m', '800m'),
(8, 8, 'Penthouse', 'Top-floor penthouse with panoramic city views.', 4, 300.00, 1, 1, 1, 2, 'Available', '200m', '100m', '300m'),
(9, 9, 'Villa', 'Exclusive villa with private pool.', 10, 400.00, 1, 1, 1, 5, 'Available', '50m', '300m', '400m'),
(10, 10, 'Apartment', 'Affordable apartment close to the city center.', 3, 70.00, 1, 0, 1, 1, 'Available', '600m', '400m', '500m'),
(11, 11, 'Loft', 'Stylish loft in the heart of the city.', 2, 150.00, 1, 0, 1, 1, 'Available', '400m', '150m', '300m'),
(12, 12, 'Chalet', 'Cozy mountain chalet with fireplace.', 6, 180.00, 1, 1, 1, 3, 'Available', '1km', '600m', '800m'),
(13, 13, 'Bungalow', 'Beachfront bungalow in a tropical setting.', 4, 200.00, 1, 1, 1, 2, 'Available', '50m', '100m', '200m'),
(14, 14, 'Cabin', 'Secluded cabin in the woods.', 5, 120.00, 1, 1, 1, 2, 'Available', '5km', '3km', '4km'),
(15, 15, 'Studio', 'Compact studio in a quiet area.', 2, 60.00, 1, 0, 1, 1, 'Available', '500m', '300m', '400m'),
(16, 16, 'Mansion', 'Luxurious mansion with sprawling gardens.', 12, 500.00, 1, 1, 1, 6, 'Available', '1km', '500m', '700m'),
(17, 17, 'Townhouse', 'Spacious townhouse perfect for families.', 6, 160.00, 1, 1, 1, 3, 'Available', '700m', '200m', '300m'),
(18, 18, 'Villa', 'Exclusive villa with private beach access.', 8, 350.00, 1, 1, 1, 4, 'Available', '0m', '100m', '200m'),
(19, 19, 'Apartment', 'Cozy apartment for budget travelers.', 2, 50.00, 1, 0, 1, 1, 'Available', '800m', '400m', '600m'),
(20, 20, 'Cottage', 'Charming cottage with garden.', 5, 140.00, 1, 1, 1, 2, 'Available', '2km', '500m', '700m');

--------------------------------------------------
-- Insert test data into the room table
-- Room availability and pricing for specific rentals
--------------------------------------------------
INSERT INTO room (vacationRentalID, roomType, pricePerNight, availableFrom, availableTo)
VALUES 
    (1, 'Deluxe', 150.00, '2024-01-01', '2024-03-31'),
    (2, 'Standard', 120.00, '2024-04-01', '2024-06-30'),
    (3, 'Deluxe', 180.00, '2024-07-01', '2024-09-30'),
    (4, 'Suite', 250.00, '2024-10-01', '2024-12-31'),
    (5, 'Standard', 90.00, '2024-02-01', '2024-05-31'),
    (6, 'Deluxe', 140.00, '2024-06-01', '2024-09-30'),
    (7, 'Cottage', 130.00, '2024-04-01', '2024-08-31'),
    (8, 'Standard', 100.00, '2024-05-01', '2024-10-31'),
    (9, 'Deluxe', 160.00, '2024-03-01', '2024-06-30'),
    (10, 'Standard', 120.00, '2024-07-01', '2024-12-31'),
    (11, 'Economy', 85.00, '2024-01-15', '2024-04-15'),
    (12, 'Standard', 200.00, '2024-05-01', '2024-08-31'),
    (13, 'Penthouse', 300.00, '2024-06-01', '2024-11-30'),
    (14, 'Loft', 160.00, '2024-03-01', '2024-07-31'),
    (15, 'Economy', 100.00, '2024-02-01', '2024-05-31'),
    (16, 'Chalet', 220.00, '2024-06-01', '2024-09-30'),
    (17, 'Townhouse', 130.00, '2024-04-01', '2024-07-31'),
    (18, 'Studio', 70.00, '2024-03-01', '2024-10-31'),
    (19, 'Suite', 240.00, '2024-05-01', '2024-09-30'),
    (20, 'Standard', 105.00, '2024-07-01', '2024-12-31');

--------------------------------------------------
-- Insert test data into the amenity table
-- Defining various amenities available at vacation rentals
--------------------------------------------------
INSERT INTO amenity (amenityName, description)
VALUES 
    ('WiFi', 'High-speed internet access'),
    ('Air Conditioning', 'Room equipped with air conditioning'),
    ('Heating', 'Central heating system'),
    ('Parking', 'Free parking space available'),
    ('Swimming Pool', 'Access to a swimming pool'),
    ('Kitchen', 'Fully equipped kitchen'),
    ('Laundry', 'Laundry facilities available'),
    ('Gym', 'Access to a gym'),
    ('Pet Friendly', 'Pets are allowed'),
    ('Breakfast', 'Breakfast included in the stay'),
    ('Balcony', 'Room with a balcony'),
    ('Terrace', 'Access to a terrace'),
    ('Sea View', 'Room with a view of the sea'),
    ('Fireplace', 'Room equipped with a fireplace'),
    ('TV', 'Television available in the room'),
    ('Garden', 'Access to a garden'),
    ('Hot Tub', 'Hot tub available'),
    ('Sauna', 'Access to a sauna'),
    ('Barbecue', 'Barbecue facilities available'),
    ('Bicycle Rental', 'Bicycles available for rent');

--------------------------------------------------
-- Insert test data into the vacationRentalAmenity table
-- Associating amenities with vacation rentals
--------------------------------------------------
INSERT INTO vacationRentalAmenity (vacationRentalID, amenityID)
VALUES 
    (1, 1),  -- WiFi for VacationRentalID 1
    (2, 2),  -- Air Conditioning for VacationRentalID 2
    (3, 3),  -- Heating for VacationRentalID 3
    (4, 4),  -- Parking for VacationRentalID 4
    (5, 5),  -- Swimming Pool for VacationRentalID 5
    (6, 6),  -- Kitchen for VacationRentalID 6
    (7, 7),  -- Laundry for VacationRentalID 7
    (8, 8),  -- Gym for VacationRentalID 8
    (9, 9),  -- Pet Friendly for VacationRentalID 9
    (10, 10), -- Breakfast for VacationRentalID 10
    (11, 11), -- Balcony for VacationRentalID 11
    (12, 12), -- Terrace for VacationRentalID 12
    (13, 13), -- Sea View for VacationRentalID 13
    (14, 14), -- Fireplace for VacationRentalID 14
    (15, 15), -- TV for VacationRentalID 15
    (16, 16), -- Garden for VacationRentalID 16
    (17, 17), -- Hot Tub for VacationRentalID 17
    (18, 18), -- Sauna for VacationRentalID 18
    (19, 19), -- Barbecue for VacationRentalID 19
    (20, 20); -- Bicycle Rental for VacationRentalID 20

--------------------------------------------------
-- Insert test data into the booking table
-- Bookings link guests to rooms and store critical booking details
--------------------------------------------------
INSERT INTO booking (guestID, roomID, bookingDate, checkInDate, checkOutDate, totalPrice, paymentStatus, lengthOfStay, cancellationDeadline, cancellationRefund, dateOfCancellation, hostPayout, eventName, startDate, endDate, description)
VALUES
    (1, 1, NOW(), '2024-09-01', '2024-09-07', 900.00, 'Pending', 6, '2024-08-29', 800.00, NULL, 850.00, 'Beirut Energy Week', '2024-09-01', '2024-09-07', 'Regional conference in Beirut'),
    (2, 2, NOW(), '2024-09-05', '2024-09-10', 600.00, 'Paid', 5, '2024-09-03', 550.00, NULL, 580.00, 'ZeGeVege Festival', '2024-09-05', '2024-09-10', 'Celebration of sustainable living, plant-based cuisine, and eco-conscious innovation in Zagreb'),
    (3, 3, NOW(), '2024-09-10', '2024-09-15', 750.00, 'Pending', 5, '2024-09-08', 700.00, NULL, 725.00, 'Berlin Marathon', '2024-09-10', '2024-09-15', 'Running Marathon in Berlin'),
    (4, 4, NOW(), '2024-09-12', '2024-09-18', 1500.00, 'Pending', 6, '2024-09-10', 1400.00, NULL, 1450.00, 'Rome Film Festival', '2024-09-12', '2024-09-18', 'Film festival in Rome'),
    (5, 5, NOW(), '2024-09-15', '2024-09-20', 450.00, 'Paid', 5, '2024-09-13', 400.00, NULL, 425.00, 'Vienna Wine Festival', '2024-09-15', '2024-09-20', 'Austrian Wine Festival in Vienna'),
    (6, 6, NOW(), '2024-09-18', '2024-09-22', 560.00, 'Cancelled', 4, '2024-09-16', 500.00, '2024-09-18', 530.00, 'Tokyo Game Show', '2024-09-18', '2024-09-22', 'Gaming event in Tokyo'),
    (7, 7, NOW(), '2024-09-20', '2024-09-25', 650.00, 'Paid', 5, '2024-09-18', 600.00, NULL, 620.00, 'Helsinki Festival', '2024-09-20', '2024-09-25', 'Multi-arts festival in Helsinki'),
    (8, 8, NOW(), '2024-09-25', '2024-09-30', 700.00, 'Pending', 5, '2024-09-23', 650.00, NULL, 680.00, 'Brussels Jazz Weekend', '2024-09-25', '2024-09-30', 'Jazz music festival in Brussels'),
    (9, 9, NOW(), '2024-09-28', '2024-10-03', 800.00, 'Paid', 5, '2024-08-26', 750.00, NULL, 780.00, 'Ganesh Chaturthi Festival', '2024-09-28', '2024-10-03', 'Traditional festival in Mumbai'),
    (10, 10, NOW(), '2024-10-01', '2024-10-05', 480.00, 'Pending', 4, '2024-09-29', 400.00, NULL, 450.00, 'Festival of Lights', '2024-10-01', '2024-10-05', 'Lights festival in Lyon'),
    (11, 11, NOW(), '2024-10-03', '2024-10-08', 425.00, 'Paid', 5, '2024-10-01', 380.00, NULL, 410.00, 'Boulevard Festival', '2024-10-03', '2024-10-08', 'Urban music festival in Casablanca'),
    (12, 12, NOW(), '2024-10-07', '2024-10-12', 1000.00, 'Pending', 5, '2024-10-05', 950.00, NULL, 975.00, 'Manchester International Festival', '2024-10-07', '2024-10-12', 'Festival of art, music, theater, and performance in Manchester'),
    (13, 13, NOW(), '2024-10-10', '2024-10-15', 1500.00, 'Paid', 5, '2024-10-08', 1400.00, NULL, 1450.00, 'Sydney Opera Festival', '2024-10-10', '2024-10-15', 'Opera festival in Sydney'),
    (14, 14, NOW(), '2024-10-12', '2024-10-17', 800.00, 'Pending', 5, '2024-10-10', 750.00, NULL, 780.00, 'New York Film Festival', '2024-10-12', '2024-10-17', 'Film festival in New York'),
    (15, 15, NOW(), '2024-10-15', '2024-10-20', 500.00, 'Paid', 5, '2024-10-13', 450.00, NULL, 475.00, 'Celebration of Light', '2024-10-15', '2024-10-20', 'World’s longest-running offshore fireworks competition held in Vancouver'),
    (16, 16, NOW(), '2024-10-18', '2024-10-22', 1200.00, 'Cancelled', 4, '2024-10-16', 1100.00, '2024-10-18', 1150.00, 'King’s Day Festival', '2024-10-18', '2024-10-22', 'Festival honoring King Willem-Alexander’s birthday in Amsterdam'),
    (17, 17, NOW(), '2024-10-20', '2024-10-25', 650.00, 'Pending', 5, '2024-10-18', 600.00, NULL, 620.00, 'San Isidro Festival', '2024-10-20', '2024-10-25', 'Festival to honor the patron of Madrid, saint San Isidro Labrador'),
    (18, 18, NOW(), '2024-10-25', '2024-10-30', 350.00, 'Paid', 5, '2024-10-23', 300.00, NULL, 330.00, 'Hamburg Jazz Festival', '2024-10-25', '2024-10-30', 'Jazz festival in Hamburg'),
    (19, 19, NOW(), '2024-10-28', '2024-11-02', 1680.00, 'Pending', 5, '2024-10-26', 1600.00, NULL, 1650.00, 'Tango BA Festival', '2024-10-28', '2024-11-02', 'Tango Dance Festival in Buenos Aires'),
    (20, 20, NOW(), '2024-11-01', '2024-11-05', 525.00, 'Paid', 4, '2024-10-30', 500.00, NULL, 510.00, 'Sziget Festival', '2024-11-01', '2024-11-05', 'Cultural festival in Budapest');

--------------------------------------------------
-- Insert test data into the transaction table
-- Transactions (payments and refunds) linked to bookings
--------------------------------------------------
INSERT INTO transaction (guestID, bookingID, amount, transactionDate, paymentMethod, transactionType, refundProcessedDate, description)
VALUES 
    (1, 1, 900.00, '2024-09-01', 'CreditCard_Visa', 'Payment', NULL, 'Booking for vacation rental'),
    (2, 2, 600.00, '2024-09-05', 'PayPal', 'Payment', NULL, 'Booking for vacation rental'),
    (3, 3, 750.00, '2024-09-10', 'CreditCard_MasterCard', 'Payment', NULL, 'Booking for vacation rental'),
    (4, 4, 1500.00, '2024-09-12', 'BankTransfer', 'Payment', NULL, 'Booking for vacation rental'),
    (5, 5, 450.00, '2024-09-15', 'CreditCard_AMEX', 'Payment', NULL, 'Booking for vacation rental'),
    (6, 6, 560.00, '2024-09-18', 'ApplePay', 'Payment', NULL, 'Booking for vacation rental'),
    (7, 7, 650.00, '2024-09-20', 'CreditCard_Visa', 'Payment', NULL, 'Booking for vacation rental'),
    (8, 8, 700.00, '2024-09-25', 'GPay', 'Payment', NULL, 'Booking for vacation rental'),
    (9, 9, 800.00, '2024-09-28', 'Maestro', 'Payment', NULL, 'Booking for vacation rental'),
    (10, 10, 480.00, '2024-10-01', 'PayPal', 'Payment', NULL, 'Booking for vacation rental'),
    (11, 11, 200.00, '2024-09-02', 'CreditCard_Visa', 'Refund', '2024-09-02 10:00:00', 'Partial refund for early cancellation'),
    (12, 12, 150.00, '2024-09-06', 'PayPal', 'Refund', '2024-09-06 14:00:00', 'Refund due to service issues'),
    (13, 13, 100.00, '2024-09-11', 'CreditCard_MasterCard', 'Refund', '2024-09-11 16:30:00', 'Refund for service issues'),
    (14, 14, 1500.00, '2024-09-13', 'BankTransfer', 'Refund', '2024-09-13 12:00:00', 'Full refund for booking cancellation'),
    (15, 15, 450.00, '2024-09-16', 'CreditCard_AMEX', 'Refund', '2024-09-16 10:00:00', 'Full refund for booking cancellation'),
    (16, 16, 560.00, '2024-09-18', 'ApplePay', 'Refund', '2024-09-18 12:00:00', 'Refund for booking cancellation'),
    (17, 17, 650.00, '2024-09-20', 'CreditCard_Visa', 'Refund', '2024-09-20 09:00:00', 'Refund due to service issues'),
    (18, 18, 700.00, '2024-09-25', 'GPay', 'Refund', '2024-09-25 15:00:00', 'Partial refund for service issues'),
    (19, 19, 800.00, '2024-09-28', 'Maestro', 'Refund', '2024-09-28 17:00:00', 'Refund for booking cancellation'),
    (20, 20, 525.00, '2024-10-01', 'PayPal', 'Refund', '2024-10-01 11:30:00', 'Full refund for booking cancellation');

--------------------------------------------------
-- Insert test data into the rravelAdmin table
-- Admin users responsible for handling reservations and policies
--------------------------------------------------
INSERT INTO travelAdmin (name, email, phoneNumber, guestID)
VALUES
    ('Jack Haddad', 'jack.haddad@example.com', '+96171234567', 1),
    ('Ivana Horvat', 'ivana.horvat@example.hr', '+385912345678', 2),
    ('Lukas Schneider', 'lukas.schneider@example.de', '+4917612345678', 3),
    ('Giovanni Rossi', 'giovanni.rossi@example.it', '+390123456789', 4),
    ('Florian Berger', 'florian.berger@example.at', '+436641234567', 5),
    ('Sakura Tanaka', 'sakura.tanaka@example.jp', '+819012345678', 6),
    ('Aino Virtanen', 'aino.virtanen@example.fi', '+358401234567', 7),
    ('Thomas De Smedt', 'thomas.desmedt@example.be', '+32475123456', 8),
    ('Rahul Mehra', 'rahul.mehra@example.in', '+919812345678', 9),
    ('Julien Moreau', 'julien.moreau@example.fr', '+33612345678', 10),
    ('Youssef Benhaddou', 'youssef.benhaddou@example.ma', '+212612345678', 11),
    ('Liam Taylor', 'liam.taylor@example.co.uk', '+447712345678', 12),
    ('Olivia Brown', 'olivia.brown@example.au', '+611234567890', 13),
    ('Michael Johnson', 'michael.johnson@example.us', '+11234567890', 14),
    ('Sophie Chen', 'sophie.chen@example.ca', '+16041234567', 15),
    ('Sanne de Vries', 'sanne.devries@example.nl', '+31612345678', 16),
    ('Carlos Martínez', 'carlos.martinez@example.es', '+34661234567', 17),
    ('Sophie Schmidt', 'sophie.schmidt@example.de', '+491523456789', 18),
    ('Mateo Fernández', 'mateo.fernandez@example.com.ar', '+5491123456789', 19),
    ('Zsófia Kovács', 'zsofia.kovacs@example.hu', '+36201234567', 20);

--------------------------------------------------
-- Insert test data into the cancellationPolicy table
-- policies regarding booking cancellations
--------------------------------------------------
INSERT INTO cancellationPolicy (policyName, description)
VALUES 
    ('Flexible', 'Full refund up to 1 day before arrival'),
    ('Moderate', 'Full refund up to 5 days before arrival'),
    ('Strict', '50% refund up to 7 days before arrival'),
    ('Super Strict', '50% refund up to 14 days before arrival'),
    ('Non-refundable', 'No refund after booking'),
    ('Relaxed', 'Full refund up to 3 days before arrival'),
    ('Firm', '75% refund up to 2 days before arrival'),
    ('Standard', '50% refund up to 4 days before arrival'),
    ('Special', 'Full refund up to 10 days before arrival'),
    ('Custom', 'Refund terms are set by the host'),
    ('Partial Refund', '30% refund up to 3 days before arrival'),
    ('Full Refund', '100% refund up to 7 days before arrival'),
    ('Weekend Special', 'No refund on weekends'),
    ('Holiday Refund', 'Full refund on holidays'),
    ('Seasonal Refund', 'Partial refund depending on the season'),
    ('Last Minute', 'No refund for last-minute bookings'),
    ('High Season', 'Strict refund policy during high season'),
    ('Event Special', 'No refund during special events'),
    ('Flexible Plus', 'Full refund up to 2 days before arrival'),
    ('Summer Special', 'Full refund up to 7 days before arrival');

--------------------------------------------------
-- Insert test data into the vacationRentalPolicy table
-- Associating cancellation policies with vacation rentals
--------------------------------------------------
INSERT INTO vacationRentalPolicy (vacationRentalID, policyID)
VALUES 
    (1, 1),
    (2, 2),
    (3, 3),
    (4, 4),
    (5, 5),
    (6, 6),
    (7, 7),
    (8, 8),
    (9, 9),
    (10, 10),
    (11, 11),
    (12, 12),
    (13, 13),
    (14, 14),
    (15, 15),
    (16, 16),
    (17, 17),
    (18, 18),
    (19, 19),
    (20, 20);

--------------------------------------------------
-- Insert test data into the reservation table
-- Admin-handled reservation details
--------------------------------------------------
INSERT INTO reservation (bookingID, adminID, dateOfReservation, paymentStatus, lengthOfStay, cancellationPolicy, refundPolicy)
VALUES 
    (1, 1, '2024-09-01', 'Pending', 7, 'Flexible', 'Full refund up to 1 day before arrival'),
    (2, 2, '2024-09-05', 'Paid', 5, 'Moderate', 'Full refund up to 5 days before arrival'),
    (3, 3, '2024-09-10', 'Cancelled', 5, 'Strict', '50% refund up to 7 days before arrival'),
    (4, 4, '2024-09-12', 'Pending', 6, 'Super Strict', '50% refund up to 14 days before arrival'),
    (5, 5, '2024-09-15', 'Paid', 5, 'Non-refundable', 'No refund after booking'),
    (6, 6, '2024-09-18', 'Cancelled', 4, 'Relaxed', 'Full refund up to 3 days before arrival'),
    (7, 7, '2024-09-20', 'Paid', 5, 'Firm', '75% refund up to 2 days before arrival'),
    (8, 8, '2024-09-25', 'Pending', 5, 'Standard', '50% refund up to 4 days before arrival'),
    (9, 9, '2024-09-28', 'Paid', 5, 'Special', 'Full refund up to 10 days before arrival'),
    (10, 10, '2024-10-01', 'Pending', 4, 'Custom', 'Refund terms are set by the host'),
    (11, 11, '2024-10-03', 'Paid', 5, 'Partial Refund', '30% refund up to 3 days before arrival'),
    (12, 12, '2024-10-07', 'Pending', 5, 'Full Refund', '100% refund up to 7 days before arrival'),
    (13, 13, '2024-10-10', 'Paid', 5, 'Weekend Special', 'No refund on weekends'),
    (14, 14, '2024-10-12', 'Pending', 5, 'Holiday Refund', 'Full refund on holidays'),
    (15, 15, '2024-10-15', 'Paid', 5, 'Seasonal Refund', 'Partial refund depending on the season'),
    (16, 16, '2024-10-18', 'Cancelled', 4, 'Last Minute', 'No refund for last-minute bookings'),
    (17, 17, '2024-10-20', 'Pending', 5, 'High Season', 'Strict refund policy during high season'),
    (18, 18, '2024-10-25', 'Paid', 5, 'Event Special', 'No refund during special events'),
    (19, 19, '2024-10-28', 'Pending', 5, 'Flexible Plus', 'Full refund up to 2 days before arrival'),
    (20, 20, '2024-11-01', 'Paid', 4, 'Summer Special', 'Full refund up to 7 days before arrival');

--------------------------------------------------
-- Insert test data into the review table
-- Reviews from guests and hosts
--------------------------------------------------
INSERT INTO review (bookingID, reviewerID, reviewerType, rating, comment, reviewDate)
VALUES
(1, 1, 'Guest', 5, 'Fantastique expérience, je reviendrai sûrement!', '2024-09-01'), -- French
(2, 2, 'Host', 4, 'Dobar gost, ali bilo je malo buke.', '2024-09-02'), -- Croatian
(3, 3, 'Guest', 5, 'Wunderbare Erfahrung, sehr sauber!', '2024-09-03'), -- German
(4, 4, 'Host', 3, 'Soggiorno piacevole, ma il Wi-Fi era lento.', '2024-09-04'), -- Italian
(5, 5, 'Guest', 4, 'Schöner Aufenthalt, aber etwas laut.', '2024-09-05'), -- German
(6, 6, 'Host', 5, '素晴らしい滞在でした、また泊まりたいです。', '2024-09-06'), -- Japanese
(7, 7, 'Guest', 5, 'Upea kokemus, todella siisti paikka!', '2024-09-07'), -- Finnish
(8, 8, 'Host', 4, 'Goede gast, maar soms wat luidruchtig.', '2024-09-08'), -- Dutch
(9, 9, 'Guest', 4, 'बहुत अच्छा अनुभव था, लेकिन कमरा थोड़ा छोटा था।', '2024-09-09'), -- Hindi
(10, 10, 'Host', 3, 'Le séjour était bon, mais le Wi-Fi était instable.', '2024-09-10'), -- French
(11, 11, 'Guest', 5, 'تجربة رائعة، سأعود بالتأكيد!', '2024-09-11'), -- Arabic
(12, 12, 'Host', 4, 'Great guest, very respectful!', '2024-09-12'), -- English (UK)
(13, 13, 'Guest', 5, 'Had a great stay, would definitely come back!', '2024-09-13'), -- English (Australia)
(14, 14, 'Host', 3, 'The guest was a bit late, but otherwise good.', '2024-09-14'), -- English (USA)
(15, 15, 'Guest', 5, 'Amazing stay, everything was clean and tidy!', '2024-09-15'), -- English (Canada)
(16, 16, 'Host', 5, 'Uitstekende gast, zeer respectvol!', '2024-09-16'), -- Dutch
(17, 17, 'Guest', 4, 'Buena experiencia, aunque el Wi-Fi era lento.', '2024-09-17'), -- Spanish
(18, 18, 'Host', 5, 'Sehr gute Erfahrung, jederzeit wieder!', '2024-09-18'), -- German
(19, 19, 'Guest', 3, 'El lugar estaba bien, pero faltaba algo de mantenimiento.', '2024-09-19'), -- Spanish
(20, 20, 'Host', 4, 'Nagyon tisztességes vendég, de kicsit késlekedett.', '2024-09-20'); -- Hungarian



--------------------------------------------------
-- Insert test data into the customerService table
-- Customer service issues related to bookings
--------------------------------------------------
INSERT INTO customerService (bookingID, issueDescription, resolution, contactMethod, resolutionDate)
VALUES 
    (1, 'Late check-in', 'Offered late check-in', 'Phone', '2024-09-02'),
    (2, 'WiFi not working', 'Fixed WiFi issue', 'Email', '2024-09-06'),
    (3, 'Room not clean', 'Sent cleaning staff', 'Chat', '2024-09-11'),
    (4, 'No hot water', 'Repaired hot water system', 'Phone', '2024-09-13'),
    (5, 'Key not working', 'Provided new key', 'Email', '2024-09-16'),
    (6, 'Noise complaint', 'Offered room change', 'Chat', '2024-09-19'),
    (7, 'Room too cold', 'Adjusted thermostat', 'Phone', '2024-09-21'),
    (8, 'TV not working', 'Replaced TV', 'Email', '2024-09-26'),
    (9, 'No parking space', 'Arranged alternative parking', 'Chat', '2024-09-29'),
    (10, 'No towels in room', 'Delivered towels', 'Phone', '2024-10-02'),
    (11, 'Noisy neighbors', 'Spoke to neighbors', 'Email', '2024-10-04'),
    (12, 'Internet slow', 'Upgraded WiFi', 'Chat', '2024-10-08'),
    (13, 'Broken chair', 'Replaced chair', 'Phone', '2024-10-11'),
    (14, 'Shower not draining', 'Unclogged drain', 'Email', '2024-10-13'),
    (15, 'No hot water', 'Repaired hot water system', 'Chat', '2024-10-17'),
    (16, 'Air conditioning not working', 'Fixed AC', 'Phone', '2024-10-20'),
    (17, 'No blankets', 'Delivered blankets', 'Email', '2024-10-23'),
    (18, 'Broken lock', 'Fixed lock', 'Chat', '2024-10-27'),
    (19, 'Water leak', 'Repaired leak', 'Phone', '2024-10-30'),
    (20, 'Loud construction noise', 'Offered room change', 'Email', '2024-11-03');

--------------------------------------------------
-- Insert test data into the event table
-- Event details linked to specific bookings
--------------------------------------------------
INSERT INTO event (bookingID, eventName, startDate, endDate, description)
VALUES 
    (1, 'Berlin Marathon', '2024-09-08', '2024-09-10', 'Annual marathon event'),
    (2, 'Stockholm Music Festival', '2024-09-11', '2024-09-13', 'Music festival in Stockholm'),
    (3, 'Paris Fashion Week', '2024-09-14', '2024-09-20', 'Fashion event in Paris'),
    (4, 'Rome Film Festival', '2024-09-21', '2024-09-25', 'Film festival in Rome'),
    (5, 'Seoul Food Festival', '2024-09-26', '2024-09-28', 'Food festival in Seoul'),
    (6, 'Tokyo Game Show', '2024-09-29', '2024-10-01', 'Gaming event in Tokyo'),
    (7, 'Gothenburg Book Fair', '2024-10-02', '2024-10-05', 'Book fair in Gothenburg'),
    (8, 'Munich Oktoberfest', '2024-10-06', '2024-10-10', 'Beer festival in Munich'),
    (9, 'Lyon Lights Festival', '2024-10-11', '2024-10-13', 'Light festival in Lyon'),
    (10, 'Milan Fashion Week', '2024-10-14', '2024-10-18', 'Fashion event in Milan'),
    (11, 'Cairo Film Festival', '2024-10-19', '2024-10-22', 'Film festival in Cairo'),
    (12, 'London Literature Festival', '2024-10-23', '2024-10-27', 'Literature festival in London'),
    (13, 'Sydney Opera Festival', '2024-10-28', '2024-11-01', 'Opera festival in Sydney'),
    (14, 'New York Comic Con', '2024-11-02', '2024-11-05', 'Comic convention in New York'),
    (15, 'Toronto Film Festival', '2024-11-06', '2024-11-10', 'Film festival in Toronto'),
    (16, 'Zurich Art Festival', '2024-11-11', '2024-11-14', 'Art festival in Zurich'),
    (17, 'Malmo Music Festival', '2024-11-15', '2024-11-17', 'Music festival in Malmo'),
    (18, 'Hamburg Christmas Market', '2024-11-18', '2024-11-20', 'Christmas market in Hamburg'),
    (19, 'Florence Food Festival', '2024-11-21', '2024-11-24', 'Food festival in Florence'),
    (20, 'Nice Jazz Festival', '2024-11-25', '2024-11-27', 'Jazz festival in Nice');
    
--------------------------------------------------
-- Insert test data into the promotion table
-- Promotional offers for vacation rentals
--------------------------------------------------
INSERT INTO promotion (vacationRentalID, discountPercentage, startDate, endDate)
VALUES
    (1, 10.0, '2024-09-01', '2024-09-07'), 
    (2, 15.0, '2024-09-05', '2024-09-10'), 
    (3, 12.5, '2024-09-10', '2024-09-15'),  
    (4, 20.0, '2024-09-12', '2024-09-18'),
    (5, 8.0, '2024-09-15', '2024-09-20'),   
    (6, 10.0, '2024-09-18', '2024-09-22'),  
    (7, 7.5, '2024-09-20', '2024-09-25'),  
    (8, 18.0, '2024-09-25', '2024-09-30'),  
    (9, 12.0, '2024-09-28', '2024-10-03'),  
    (10, 14.0, '2024-10-01', '2024-10-05'), 
    (11, 9.5, '2024-10-03', '2024-10-08'),  
    (12, 11.0, '2024-10-07', '2024-10-12'),
    (13, 25.0, '2024-10-10', '2024-10-15'),
    (14, 19.0, '2024-10-12', '2024-10-17'),
    (15, 15.0, '2024-10-15', '2024-10-20'),
    (16, 17.5, '2024-10-18', '2024-10-22'), 
    (17, 20.0, '2024-10-20', '2024-10-25'), 
    (18, 5.0, '2024-10-25', '2024-10-30'),  
    (19, 22.0, '2024-10-28', '2024-11-02'), 
    (20, 10.0, '2024-11-01', '2024-11-05'); 

-- Enable foreign key checks after all tables are created and data inserted
SET FOREIGN_KEY_CHECKS = 1;

-- Verify data by selecting from the Guest table
SELECT * FROM guest;

-- Verify data by selecting from the Host table
SELECT * FROM host;

-- Verify data by selecting from the VacationRental table
SELECT * FROM VacationRental;

-- Verify data by selecting from the Room table
SELECT * FROM room;

-- Verify data by selecting from the Amenity table
SELECT * FROM amenity;

-- Verify data by selecting from the VacationRentalAmenity table
SELECT * FROM vacationRentalAmenity;

-- Verify data by selecting from the CancellationPolicy table
SELECT * FROM cancellationPolicy;

-- Verify data by selecting from the VacationRentalPolicy table
SELECT * FROM vacationRentalPolicy;

-- Verify data by selecting from the Booking table
SELECT * FROM booking;

-- Verify data by selecting from the Transaction table
SELECT * FROM transaction;

-- Verify data by selecting from the Review table
SELECT * FROM review;

-- Verify data by selecting from the CustomerService table
SELECT * FROM customerService;

-- Verify data by selecting from the Event table
SELECT * FROM event;

-- Verify data by selecting from the Promotion table
SELECT * FROM promotion;

-- Verify data by selecting from the Notification table
SELECT * FROM notification;

-- Verify data by selecting from the LoginHistory table
SELECT * FROM loginHistory;

-- Verify data by selecting from the SocialNetwork table
SELECT * FROM socialNetwork;

-- Verify data by selecting from the GuestSocialNetwork table
SELECT * FROM guestSocialNetwork;

-- Verify data by selecting from the City table
SELECT * FROM city;

-- Verify data by selecting from the Location table
SELECT * FROM location;

-- Verify data by selecting from the TravelAdmin table
SELECT * FROM travelAdmin;

-- Verify data by selecting from the Reservation table
SELECT * FROM reservation;

--------------------------------------------------
-- Data Integrity Check: Orphaned Bookings
-- This query checks for bookings that are not linked to any guest.
--------------------------------------------------
SELECT b.bookingID, b.guestID, g.Name
FROM booking b
LEFT JOIN guest g ON b.guestID = g.guestID
WHERE g.guestID IS NULL;

-- Test Case 1: Retrieve guest booking details, host details, and vacation rental details.
-- Verifies if the join across Booking, Guest, Room, VacationRental, and Host is working as expected.
SELECT 
    g.Name AS guestName,
    b.bookingDate,
    b.checkInDate,
    b.checkOutDate,
    b.totalPrice,
    vr.propertyType,
    h.hostID,
    h.rating AS HostRating
FROM booking b
JOIN guest g ON b.guestID = g.guestID
JOIN room r ON b.roomID = r.roomID
JOIN vacationRental vr ON r.vacationRentalID = vr.vacationRentalID
JOIN host h ON vr.hostID = h.hostID
ORDER BY b.bookingDate DESC;

--------------------------------------------------
-- Test Case 2: Retrieve payment and refund details for each booking, along with guest information.
-- Tests the Transaction-Booking-Guest relationship.
--------------------------------------------------
SELECT 
    g.Name AS guestName,
    b.bookingDate,
    t.amount AS TransactionAmount,
    t.transactionDate,
    t.transactionType,
    t.refundProcessedDate,
    t.description AS transactionDescription
FROM transaction t
JOIN booking b ON t.bookingID = b.bookingID
JOIN guest g ON t.guestID = g.guestID
ORDER BY t.transactionDate DESC;

--------------------------------------------------
-- Test Case 3: Retrieve guest reviews, customer service details, and property information.
-- Tests the Review and CustomerService tables along with Booking, Guest, and VacationRental.
--------------------------------------------------
SELECT 
    g.Name AS guestName,
    vr.propertyType,
    r.rating AS reviewRating,
    r.Comment AS reviewComment,
    cs.issueDescription AS customerServiceIssue,
    cs.resolution AS customerServiceResolution,
    cs.contactMethod AS customerServiceContact
FROM guest g
JOIN booking b ON g.guestID = b.guestID
JOIN review r ON b.bookingID = r.bookingID
LEFT JOIN customerService cs ON b.bookingID = cs.bookingID
JOIN room rm ON b.roomID = rm.roomID
JOIN vacationRental vr ON rm.vacationRentalID = vr.vacationRentalID
JOIN host h ON vr.hostID = h.hostID
ORDER BY g.name ASC;

--------------------------------------------------
-- Test Case 4: Retrieve details for cancelled bookings along with guest information
--------------------------------------------------
SELECT 
    b.bookingID,
    g.name AS guestName,
    b.roomID,
    b.totalPrice,
    b.cancellationRefund,
    b.dateOfCancellation
FROM 
    booking b
JOIN 
    guest g ON b.guestID = g.guestID
WHERE 
    b.paymentStatus = 'Cancelled'
ORDER BY 
    b.dateOfCancellation DESC;

--------------------------------------------------
-- Test Case 5: VacationRental Location and City
--------------------------------------------------
SELECT 
    vr.vacationRentalID,
    vr.propertyType,
    l.partOfCity,
    c.cityName,
    c.country
FROM vacationRental vr
JOIN location l ON vr.locationID = l.locationID
JOIN city c ON l.cityID = c.cityID
ORDER BY vr.vacationRentalID;

--------------------------------------------------
-- Test Case 6: Promotions for Vacation Rentals
-------------------------------------------------- 
SELECT 
    vr.propertyType,
    p.discountPercentage,
    p.startDate,
    p.endDate
FROM vacationRental vr
JOIN promotion p ON vr.vacationRentalID = p.vacationRentalID
ORDER BY p.startDate;


-- Enable foreign key checks after all tables are created and data inserted
SET FOREIGN_KEY_CHECKS = 1;
