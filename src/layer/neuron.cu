/*
 * neuron.cu
 *
 *  Created on: Sep 20, 2015
 *      Author: lyx
 */

#include "neuron.cuh"

using namespace global;

namespace layer {

Neuron::Neuron(Layer* _prev, int _output_size) {
	prev = _prev;
	prev->next = this;

	int _n, _c, _h, _w, _tmp;
	cudnnDataType_t _t;
	callCudnn(cudnnGetTensor4dDescriptor(prev->t_data, &_t, &_n, &_c, &_h, &_w, &_tmp,
			&_tmp, &_tmp, &_tmp));
	batch = _n;
	input_size = _c;
	output_size = _output_size;
	callCudnn(cudnnCreateTensorDescriptor(&t_data));
	callCudnn(cudnnSetTensor4dDescriptor(t_data, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT,
			_n, output_size, 1, 1));
	data_size = _n * output_size;
	callCuda(cudaMalloc(&data, sizeof(float) * data_size));
	callCuda(cudaMalloc(&tmp_data, sizeof(float) * data_size));
	callCuda(cudaMalloc(&diff, sizeof(float) * prev->data_size));
	callCuda(cudaMalloc(&tmp_diff, sizeof(float) * data_size));

	param_size = _c * output_size;
	param_bias_size = output_size;
	callCuda(cudaMalloc(&param, sizeof(float) * param_size));
	callCuda(cudaMalloc(&param_bias, sizeof(float) * param_bias_size));
	callCuda(cudaMalloc(&gradient, sizeof(float) * param_size));
	callCuda(cudaMalloc(&gradient_bias, sizeof(float) * param_bias_size));
	utils::setGpuNormalValue(param, param_size);
	utils::setGpuNormalValue(param_bias, param_bias_size);

	callCuda(cudaMalloc(&one, sizeof(float) * batch));
	utils::setGpuValue(ont, batch, 1);
}

Neuron::~Neuron() {
	callCudnn(cudnnDestroyTensorDescriptor(t_data));
	callCuda(cudaFree(data));
	callCuda(cudaFree(tmp_data));
	callCuda(cudaFree(diff));
	callCuda(cudaFree(tmp_diff));
	callCuda(cudaFree(param));
	callCuda(cudaFree(param_bias));
	callCuda(cudaFree(gradient));
	callCuda(cudaFree(gradient_bias));
	callCuda(cudaFree(one));
}

void Neuron::forward() {
	float a = 1;
	float b = 0;
	callCuda(cublasSgemm(cublasHandle, CUBLAS_OP_T, CUBLAS_OP_N, output_size, batch,
			input_size,	&a, param, input_size, prev->data, input_size, &b, tmp_data,
			output_size));
	callCuda(cublasSgemm(cublasHandle, CUBLAS_OP_N, CUBLAS_OP_N, output_size, batch,
			1, &a, param_bias, output_size,	one, 1,	&a,	tmp_data, output_size));
	forward_activation();
}

void Neuron::backward() {
	float a = 1;
	float b = 0;
	backward_activation();
	callCuda(cublasSgemm(cublasHandle, CUBLAS_OP_N, CUBLAS_OP_T, input_size,
			output_size, batch, &a, prev->data, input_size, next->diff, output_size,
			&b, gradient, input_size));
	callCuda(cublasSgemv(cublasHandle, CUBLAS_OP_N, output_size, batch,
			&a, next->diff, output_size, one, 1, &b, gradient_bias, 1));
	callCuda(cublasSgemm(cublasHandle, CUBLAS_OP_N, CUBLAS_OP_N, input_size,
			batch, output_size, &a, param, input_size, next->diff, output_size,
			&b, diff, input_size));
}

void Neuron::update(float alpha) {
	callCuda(cublasSaxpy(cublasHandle, param_size, &alpha, gradient, 1, param, 1));
	callCuda(cublasSaxpy(cublasHandle, param_bias_size,	&alpha,
			gradient_bias, 1, param_bias, 1));
}

}