output "ec2_instance_id" {
    value = aws_instance.web_server.id
}

output "lambda_function_url" {
    value = aws_lambda_function_url.secure_url.function_url
}
