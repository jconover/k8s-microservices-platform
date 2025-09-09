import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import { Container, AppBar, Toolbar, Typography, Button, Grid, Card, CardContent } from '@mui/material';
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || '/api';

function Home() {
  const [services, setServices] = useState([]);
  
  useEffect(() => {
    checkServices();
  }, []);
  
  const checkServices = async () => {
    const serviceList = ['user', 'product', 'order', 'notification'];
    const checks = await Promise.all(
      serviceList.map(async (service) => {
        try {
          const response = await axios.get(`${API_URL}/${service}/health`);
          return { name: service, status: 'healthy', ...response.data };
        } catch (error) {
          return { name: service, status: 'error' };
        }
      })
    );
    setServices(checks);
  };
  
  return (
    <Container>
      <Typography variant="h3" gutterBottom>
        Microservices Platform
      </Typography>
      <Grid container spacing={3}>
        {services.map((service) => (
          <Grid item xs={12} sm={6} md={3} key={service.name}>
            <Card>
              <CardContent>
                <Typography variant="h5">{service.name}</Typography>
                <Typography color={service.status === 'healthy' ? 'green' : 'red'}>
                  Status: {service.status}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Container>
  );
}

function App() {
  return (
    <Router>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" sx={{ flexGrow: 1 }}>
            Kubernetes Microservices Demo
          </Typography>
          <Button color="inherit" component={Link} to="/">Home</Button>
          <Button color="inherit" component={Link} to="/users">Users</Button>
          <Button color="inherit" component={Link} to="/products">Products</Button>
          <Button color="inherit" component={Link} to="/orders">Orders</Button>
        </Toolbar>
      </AppBar>
      <Container sx={{ mt: 4 }}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/users" element={<div>Users Page</div>} />
          <Route path="/products" element={<div>Products Page</div>} />
          <Route path="/orders" element={<div>Orders Page</div>} />
        </Routes>
      </Container>
    </Router>
  );
}

export default App;