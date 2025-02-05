/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*!
 *  Copyright (c) 2015 by Contributors
 * \file c_api_error.h
 * \brief Error handling for C API.
 */
#ifndef MXNET_C_API_C_API_COMMON_H_
#define MXNET_C_API_C_API_COMMON_H_

#include <dmlc/base.h>
#include <dmlc/logging.h>
#include <dmlc/thread_local.h>
#include <mxnet/base.h>
#include <mxnet/c_api.h>
#include <nnvm/graph.h>
#include <string>
#include <vector>

#include <mxnet/executor.h>
#include <mxnet/ndarray.h>

/*! \brief  macro to guard beginning and end section of all functions */
#define API_BEGIN() try { on_enter_api(__FUNCTION__);
/*! \brief every function starts with API_BEGIN();
     and finishes with API_END() or API_END_HANDLE_ERROR */
#define API_END() } catch(dmlc::Error &_except_) { on_exit_api(); return MXAPIHandleException(_except_); } on_exit_api(); return 0;  // NOLINT(*)

/*!
 * \brief every function starts with API_BEGIN();
 *   and finishes with API_END() or API_END_HANDLE_ERROR
 *   The finally clause contains procedure to cleanup states when an error
 * happens.
 */
#define API_END_HANDLE_ERROR(Finalize) } catch(dmlc::Error &_except_) { Finalize; on_exit_api(); return MXAPIHandleException(_except_); } on_exit_api(); return 0; // NOLINT(*)

/*!
 * \brief Set the last error message needed by C API
 * \param msg The error message to set.
 */
void MXAPISetLastError(const char *msg);
/*!
 * \brief handle exception throwed out
 * \param e the exception
 * \return the return value of API after exception is handled
 */
inline int MXAPIHandleException(const dmlc::Error &e) {
  MXAPISetLastError(e.what());
  return -1;
}

using namespace mxnet;

/*! \brief entry to to easily hold returning information */
struct MXAPIThreadLocalEntry {
  /*! \brief result holder for returning string */
  std::string ret_str;
  /*! \brief result holder for returning strings */
  std::vector<std::string> ret_vec_str;
  /*! \brief result holder for returning string pointers */
  std::vector<const char *> ret_vec_charp;
  /*! \brief result holder for returning handles */
  std::vector<void *> ret_handles;
  /*! \brief holder for NDArray handles */
  std::vector<NDArray *> ndinputs, ndoutputs;
  /*! \brief result holder for returning shapes */
  std::vector<TShape> arg_shapes, out_shapes, aux_shapes;
  /*! \brief result holder for returning type flags */
  std::vector<int> arg_types, out_types, aux_types;
  /*! \brief result holder for returning storage types */
  std::vector<int> arg_storage_types, out_storage_types, aux_storage_types;
  /*! \brief result holder for returning shape dimensions */
  std::vector<mx_uint> arg_shape_ndim, out_shape_ndim, aux_shape_ndim;
  /*! \brief result holder for returning shape pointer */
  std::vector<const mx_uint *> arg_shape_data, out_shape_data, aux_shape_data;
  /*! \brief uint32_t buffer for returning shape pointer */
  std::vector<uint32_t> arg_shape_buffer, out_shape_buffer, aux_shape_buffer;
  /*! \brief bool buffer */
  std::vector<bool> save_inputs, save_outputs;
  // helper function to setup return value of shape array
  inline static void SetupShapeArrayReturnWithBuffer(const std::vector<TShape> &shapes, std::vector<mx_uint> *ndim,
                                                     std::vector<const mx_uint *> *data,
                                                     std::vector<uint32_t> *buffer) {
    ndim->resize(shapes.size());
    data->resize(shapes.size());
    size_t size = 0;
    for (const auto &s : shapes)
      size += s.ndim();
    buffer->resize(size);
    uint32_t *ptr = buffer->data();
    for (size_t i = 0; i < shapes.size(); ++i) {
      ndim->at(i) = shapes[i].ndim();
      data->at(i) = ptr;
      ptr         = nnvm::ShapeTypeCast(shapes[i].begin(), shapes[i].end(), ptr);
    }
  }
};

// define the threadlocal store.
typedef dmlc::ThreadLocalStore<MXAPIThreadLocalEntry> MXAPIThreadLocalStore;

namespace mxnet {
// copy attributes from inferred vector back to the vector of each type.
template <typename AttrType>
inline void CopyAttr(const nnvm::IndexedGraph &idx, const std::vector<AttrType> &attr_vec,
                     std::vector<AttrType> *in_attr, std::vector<AttrType> *out_attr, std::vector<AttrType> *aux_attr) {
  in_attr->clear();
  out_attr->clear();
  aux_attr->clear();
  for (uint32_t nid : idx.input_nodes()) {
    if (idx.mutable_input_nodes().count(nid) == 0) {
      in_attr->push_back(attr_vec[idx.entry_id(nid, 0)]);
    } else {
      aux_attr->push_back(attr_vec[idx.entry_id(nid, 0)]);
    }
  }
  for (auto &e : idx.outputs()) {
    out_attr->push_back(attr_vec[idx.entry_id(e)]);
  }
}

// stores keys that will be converted to __key__
extern const std::vector<std::string> kHiddenKeys;

extern void on_enter_api(const char *function);
extern void on_exit_api();

}  // namespace mxnet

// predictor interface
struct MXAPIPredictor {
  // output arrays
  std::vector<NDArray> out_arrays;
  // argument arrays
  std::vector<NDArray> arg_arrays;
  // output shapes
  std::vector<TShape> out_shapes;
  // uint32_t buffer for output shapes
  std::vector<uint32_t> out_shapes_buffer;
  // key to arguments
  std::unordered_map<std::string, size_t> key2arg;
  // executor
  std::unique_ptr<Executor> exec;
  // handle id
  std::string handle_id;
  // model name
  std::string model_name;
  // model id to be used when opening / closing
  std::string model_id;
};

} // namespace mxnet

#endif // MXNET_C_API_C_API_COMMON_H_
