FROM public.ecr.aws/lambda/python:3.12

# Copy function code
COPY handler.py ./

# Copy requirements and install
COPY requirements.txt .
RUN pip install --upgrade --no-cache-dir -r requirements.txt

# Set the Lambda handler
CMD ["handler.lambda_handler"] 