#🏢 hostel
CREATE TABLE hostel (
    id BIGSERIAL PRIMARY KEY,
    hostel_name VARCHAR(50) NOT NULL,
    hostel_type VARCHAR(20) NOT NULL DEFAULT 'boys',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

👤 api_allowed_user
CREATE TABLE api_allowed_user (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    hostel_id BIGINT NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (hostel_id) REFERENCES hostel(id) ON DELETE CASCADE
);

👤 user
CREATE TABLE "user" (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    student_id VARCHAR(20) UNIQUE,
    phone VARCHAR(20) UNIQUE,

    password VARCHAR(128) NOT NULL,

    is_staff BOOLEAN DEFAULT FALSE,
    is_superuser BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    date_joined TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    hostel_id BIGINT,
    role VARCHAR(20) DEFAULT 'student',
    allowed_user_id BIGINT UNIQUE,

    FOREIGN KEY (hostel_id) REFERENCES hostel(id) ON DELETE CASCADE,
    FOREIGN KEY (allowed_user_id) REFERENCES api_allowed_user(id) ON DELETE SET NULL
);

🔑 otp
CREATE TABLE otp (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

🍽 item
CREATE TABLE item (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    is_veg BOOLEAN DEFAULT TRUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

🍱 combo
CREATE TABLE combo (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    meal_type VARCHAR(20) NOT NULL,
    category VARCHAR(20) NOT NULL,   -- veg / nonveg
    price DECIMAL(8,2) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

🔗 combo_items (M2M)
CREATE TABLE combo_items (
    id BIGSERIAL PRIMARY KEY,
    combo_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,

    FOREIGN KEY (combo_id) REFERENCES combo(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES item(id) ON DELETE CASCADE,

    UNIQUE (combo_id, item_id)
);

⏰ meal_slot
CREATE TABLE meal_slot (
    id BIGSERIAL PRIMARY KEY,
    day VARCHAR(20) NOT NULL,
    slot VARCHAR(10) NOT NULL,
    date DATE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (day, slot, date)
);

🔗 meal_slot_combos (max 2 combos logic)
CREATE TABLE meal_slot_combos (
    id BIGSERIAL PRIMARY KEY,
    meal_slot_id BIGINT NOT NULL,
    combo_id BIGINT NOT NULL,

    FOREIGN KEY (meal_slot_id) REFERENCES meal_slot(id) ON DELETE CASCADE,
    FOREIGN KEY (combo_id) REFERENCES combo(id) ON DELETE CASCADE,

    UNIQUE (meal_slot_id, combo_id)
);

📋 booking
CREATE TABLE booking (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    date DATE NOT NULL,

    qr_uuid UUID UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,

    UNIQUE (user_id, date)
);


🍴 booking_meal (MAIN TABLE)
CREATE TABLE booking_meal (
    id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,
    meal_slot_id BIGINT NOT NULL,
    combo_id BIGINT NOT NULL,

    status VARCHAR(10) DEFAULT 'booked',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (booking_id) REFERENCES booking(id) ON DELETE CASCADE,
    FOREIGN KEY (meal_slot_id) REFERENCES meal_slot(id) ON DELETE CASCADE,
    FOREIGN KEY (combo_id) REFERENCES combo(id) ON DELETE CASCADE,

    UNIQUE (booking_id, meal_slot_id)
);

⭐ feedback
CREATE TABLE feedback (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL,
    booking_meal_id BIGINT NOT NULL,
    combo_id BIGINT NOT NULL,
    hostel_id BIGINT NOT NULL,

    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,
    FOREIGN KEY (booking_meal_id) REFERENCES booking_meal(id) ON DELETE CASCADE,
    FOREIGN KEY (combo_id) REFERENCES combo(id) ON DELETE CASCADE,
    FOREIGN KEY (hostel_id) REFERENCES hostel(id) ON DELETE CASCADE,

    UNIQUE (user_id, booking_meal_id)
);