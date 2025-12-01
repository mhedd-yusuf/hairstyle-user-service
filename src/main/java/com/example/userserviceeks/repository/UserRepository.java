package com.example.userserviceeks.repository;


import com.example.userserviceeks.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {
}
