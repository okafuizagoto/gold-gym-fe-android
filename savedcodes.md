user
SELECT user_id, email,password,nama,nomorhp,nomorkartu,cvv,expireddate,namapemegangkartu,validasiyn, token, otp, updated_by, updated_at, last_login, last_login_host, force_change_password 
FROM peserta

item
SELECT id, user_id, code, name, type, brand, description, status, created_at, updated_at
FROM items;