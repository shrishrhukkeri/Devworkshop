package com.exam;

import org.junit.Assert;
import org.junit.Test;

public class AppTest {

    @Test
    public void test() {
	System.out.println("Environment: " + System.getProperty("env.name"));     
    }
}
