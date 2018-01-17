function gx_box_jsoc_make_query,t1,t2,ds,segment, waves = waves
  query = ssw_jsoc_time2query(t1, t2, ds=ds)
  if keyword_set(waves) then query=query+'['+arr2str(strtrim(waves,2))+']'
  query=query+'{'+segment+'}'
  return, query[0]
end


;+
    ; :Description:
    ;    Trys to locate predownloaded data in local cache directory
    ;
    ; :Params:
    ;    dir - cache directory
    ;    query - JSOC query
    ;
    ;
    ;
    ; :Author: Sergey Anfinogentov
    ;-
function gx_box_jsoc_try_cache, dir, query
  index_file = filepath('index.sav', root = dir)
  If not file_test(index_file) then begin
    queries = []
    files = []
    save, queries, files, file = index_file
    return, ''
  Endif
  restore, index_file
  if n_elements(queries) eq 0 then return, ''
  ind = where(queries eq query)
  if ind[0] eq -1 then return, ''
  return, files[ind]
end

;+
    ; :Description:
    ;    Saves downloaded data into local cache
    ;
    ; :Params:
    ;    dir - cache directory
    ;    query - JSOC query associated with the data
    ;    data - data array
    ;    index - index structure
    ;    file - filename obtained with the GX_BOX_JSOC_MAKE_FILENAME routine
    ;
    ;
    ;
    ; :Author: Sergey Anfinogentov
    ;-
pro gx_box_jsoc_save2cache, dir, query, data, index, file
  index_file = filepath('index.sav', root = dir)
  If not file_test(index_file) then begin
    queries = []
    files = []
  Endif else restore, index_file
  if n_elements(queries) eq 0 then begin
    queries = []
    files = [] 
  endif
  
  
 ; file = gx_box_jsoc_make_filename(index, ds, wave)
  
  date_dir = anytim(strreplace(index.t_rec,'.','-'),/ccsds,/date)
  file_mkdir,filepath( date_dir, root = dir)
  
  local_file = filepath(file, subdir = date_dir, root = dir)
  
  writefits, local_file, data, struct2fitshead(index)
  
  queries = [queries, query]
  files = [files, local_file]
  
  save, queries, files, file = index_file
  
end

function gx_box_jsoc_make_filename, index, ds, segment, wave = wave
  
  time_s = strreplace(index.t_rec,'.','')
  time_s = strreplace(time_s,':','')
  
  if keyword_set(wave) then begin
    file = ds+'.'+time_S+'.'+segment+'.'+wave+'.fits'
  endif else begin
    file = ds+'.'+time_S+'.'+segment+'.fits'
  endelse
  return, file
end


function gx_box_jsoc_get_fits, t1, t2, ds, segment, cache_dir, wave = wave

  query = gx_box_jsoc_make_query(t1,t2,ds,segment, wave = wave)
  
  result = gx_box_jsoc_try_cache(cache_dir, query)
  
  if result ne '' then return, result


  ssw_jsoc_time2data, t1, t2, index, urls, /urls_only, ds=ds, segment=segment, wave=wave
 
  index = index[0]
  url  = urls[0] 
  local_file = gx_box_jsoc_make_filename(index, ds, segment,wave = wave)
  tmp_dir = GETENV('IDL_TMPDIR')
  tmp_file = filepath(local_file, /tmp)
  
  sock_copy,url, tmp_file
  read_sdo, tmp_file, tmp_index, data, /uncomp_delete
  file_delete, tmp_file
  
  gx_box_jsoc_save2cache, cache_dir, query, data, index, file_basename(local_file)
  return, gx_box_jsoc_try_cache(cache_dir, query)
  
end

pro gx_box_download_jsoc_data_get_fits, t1, t2, ds, segment, out_dir, cache_dir = cache_dir, waves = waves
  ssw_jsoc_time2data, t1, t2, index, urls, /urls_only, ds=ds, segment=segment, waves=waves
  
  ;Select only the first image if multiple images were found
  index = index[0]
  urls  = urls[0]
  
;  time_s = strreplace(index.t_rec,'.','')
;  time_s = strreplace(time_s,':','')
;  if keyword_set(waves) then begin
;    out_file = ds+'.'+time_S+'.'+segment+'.'+waves+'.fits'
;  endif else begin
;    out_file = ds+'.'+time_S+'.'+segment+'.fits'
;  endelse
  out_file = gx_box_jsoc_make_filename(index, ds,segment, wave = waves)
  out_file = filepath(out_file, root = out_dir)
  data_file = gx_box_download_jsoc(urls, cache_dir = cache_dir)
  if !VERSION.OS_FAMILY eq "unix" then  begin
    read_sdo,data_file, temp_index, data, /use_shared_lib
  endif else begin
    read_sdo,data_file, temp_index, data, /uncomp_delete
  endelse
  mwritefits,index, data, outfile = out_file
end