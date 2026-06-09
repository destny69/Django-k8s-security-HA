from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase


class JwtAuthTests(APITestCase):
	def test_register_login_and_me(self):
		register_response = self.client.post(
			reverse("register"),
			{
				"username": "alice",
				"email": "alice@example.com",
				"password": "strongpass123",
			},
			format="json",
		)

		self.assertEqual(register_response.status_code, status.HTTP_201_CREATED)
		self.assertTrue(User.objects.filter(username="alice").exists())

		login_response = self.client.post(
			reverse("token_obtain_pair"),
			{
				"username": "alice",
				"password": "strongpass123",
			},
			format="json",
		)

		self.assertEqual(login_response.status_code, status.HTTP_200_OK)
		self.assertIn("access", login_response.data)
		self.assertIn("refresh", login_response.data)

		self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {login_response.data["access"]}')
		me_response = self.client.get(reverse("me"))

		self.assertEqual(me_response.status_code, status.HTTP_200_OK)
		self.assertEqual(me_response.data["username"], "alice")
