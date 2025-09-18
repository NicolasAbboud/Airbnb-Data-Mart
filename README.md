# Airbnb Data Mart

## 📌 Overview
This project implements a relational database for the Airbnb use case, modeling how hosts list properties, guests book accommodations, and transactions are processed. The database is designed in MySQL (SQL standard compatible) and follows best practices of normalization to reduce redundancy and ensure data integrity.

## 🎯 Objectives
- Build an Entity Relationship Model (ERM) for Airbnb data.
- Implement a normalized SQL schema with relationships and constraints.
- Populate tables with dummy data (≥20 rows per table).
- Provide test cases to validate the schema.
- Document SQL statements, results, and insights.

## 🗂️ Database Schema
The main entities and relationships include:
- *Guest* – Core user profile (guests can also be hosts).
- *Host* – Property owners linked to guests.
- *TravelAdmin* – Platform administrators overseeing reservations.
- *SocialNetwork / GuestSocialNetwork* – Social media integration.
- *LoginHistory / Notification* – Security and communication logs.
- *City / Location* – Geographical data.
- *VacationRental / Room* – Property and room listings.
- *Amenity / VacationRentalAmenity* – Features available per property.
- *CancellationPolicy / VacationRentalPolicy* – Refund rules.
- *Booking / Transaction / Reservation* – Reservation and payment flow.
- *Review* – Guest ↔ Host feedback system.
- *CustomerService* – Support ticket management.
- *Event / Promotion* – Local events and discount campaigns.

## 📊 Dummy Data
- Each table is populated with at least 20 records.
- Data includes realistic values (names, cities, amenities, bookings).
- Allows meaningful query results for demonstration.

## ⚙️ Setup Instructions
*1. Clone Repository / Get Files*
``
git clone <repo_url>
cd airbnb-database
``

*2. Create Database in MySQL*
``
CREATE DATABASE airbnb_datamart_nicolas;
``

*3. Run SQL Script*
``
mysql -u <username> -p airbnb_datamart_nicolas < sql_file_airbnb_datamart.sql
``

*4. Verify Tables*
``
SHOW TABLES;
``


