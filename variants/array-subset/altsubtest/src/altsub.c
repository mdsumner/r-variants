#include <R.h>
#include <Rinternals.h>
#include <R_ext/Altrep.h>
#include <R_ext/Rdynload.h>

static R_altrep_class_t altsub_class;
static double n_method = 0, n_elt = 0;
static SEXP kept = NULL;   /* the vector "shared" mode hands back */

/* data1: plain double payload; data2: integer mode */
static R_xlen_t altsub_Length(SEXP x) { return XLENGTH(R_altrep_data1(x)); }
static double altsub_Elt(SEXP x, R_xlen_t i)
{
    n_elt++;
    return REAL(R_altrep_data1(x))[i];
}
static void *altsub_Dataptr(SEXP x, Rboolean writable)
{
    return DATAPTR(R_altrep_data1(x));
}
static const void *altsub_Dataptr_or_null(SEXP x) { return NULL; }
static Rboolean altsub_Inspect(SEXP x, int pre, int deep, int pvec,
			       void (*inspect_subtree)(SEXP, int, int, int))
{
    Rprintf(" altsub mode %d\n", INTEGER(R_altrep_data2(x))[0]);
    return TRUE;
}

#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET
static SEXP compute(SEXP x, SEXP subs, SEXP dim)
{
    int k = LENGTH(subs);
    const int *pd = INTEGER(dim);
    const double *px = REAL(R_altrep_data1(x));
    R_xlen_t n = 1;
    for (int d = 0; d < k; d++) n *= XLENGTH(VECTOR_ELT(subs, d));
    SEXP ans = PROTECT(allocVector(REALSXP, n));
    int *pos = (int *) R_alloc(k, sizeof(int));
    for (int d = 0; d < k; d++) pos[d] = 0;
    for (R_xlen_t i = 0; i < n; i++) {
	R_xlen_t off = 0, stride = 1;
	int na = 0;
	for (int d = 0; d < k; d++) {
	    int s = INTEGER(VECTOR_ELT(subs, d))[pos[d]];
	    if (s == NA_INTEGER) { na = 1; break; }
	    off += (R_xlen_t) (s - 1) * stride;
	    stride *= pd[d];
	}
	REAL(ans)[i] = na ? NA_REAL : px[off];
	for (int d = 0; d < k; d++) {
	    if (++pos[d] < XLENGTH(VECTOR_ELT(subs, d))) break;
	    pos[d] = 0;
	}
    }
    UNPROTECT(1);
    return ans;
}

static SEXP altsub_Extract_array_subset(SEXP x, SEXP subs, SEXP dim,
					SEXP call)
{
    n_method++;
    int mode = INTEGER(R_altrep_data2(x))[0];
    SEXP ans;
    switch (mode) {
    case 1: return NULL;
    case 2: return R_NilValue;
    case 3:
	ans = PROTECT(compute(x, subs, dim));
	ans = xlengthgets(ans, XLENGTH(ans) - 1);
	UNPROTECT(1);
	return ans;
    case 4:
	ans = PROTECT(compute(x, subs, dim));
	setAttrib(ans, R_NamesSymbol,
		  PROTECT(allocVector(STRSXP, XLENGTH(ans))));
	UNPROTECT(2);
	return ans;
    case 5:
	if (kept != NULL) R_ReleaseObject(kept);
	kept = compute(x, subs, dim);
	R_PreserveObject(kept);
	MARK_NOT_MUTABLE(kept);
	return kept;
    case 6:
	ans = PROTECT(compute(x, subs, dim));
	for (int d = 0; d < LENGTH(subs); d++) {
	    SEXP s = VECTOR_ELT(subs, d);
	    for (R_xlen_t j = 0; j < XLENGTH(s); j++) INTEGER(s)[j] = 1;
	}
	UNPROTECT(1);
	return ans;
    default:
	return compute(x, subs, dim);
    }
}
#endif

static SEXP C_altsub_make(SEXP x, SEXP mode)
{
    SEXP data = PROTECT(duplicate(x));
    SET_ATTRIB(data, R_NilValue);
    SEXP ans = R_new_altrep(altsub_class, data, mode);
    UNPROTECT(1);
    return ans;
}

static SEXP C_altsub_counts(SEXP reset)
{
    SEXP ans = PROTECT(allocVector(REALSXP, 2));
    REAL(ans)[0] = n_method;
    REAL(ans)[1] = n_elt;
    SEXP nm = PROTECT(allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, mkChar("method"));
    SET_STRING_ELT(nm, 1, mkChar("elt"));
    setAttrib(ans, R_NamesSymbol, nm);
    if (asLogical(reset)) n_method = n_elt = 0;
    UNPROTECT(2);
    return ans;
}

static const R_CallMethodDef callMethods[] = {
    {"C_altsub_make", (DL_FUNC) &C_altsub_make, 2},
    {"C_altsub_counts", (DL_FUNC) &C_altsub_counts, 1},
    {NULL, NULL, 0}
};

void R_init_altsubtest(DllInfo *dll)
{
    altsub_class = R_make_altreal_class("altsub", "altsubtest", dll);
    R_set_altrep_Length_method(altsub_class, altsub_Length);
    R_set_altrep_Inspect_method(altsub_class, altsub_Inspect);
    R_set_altvec_Dataptr_method(altsub_class, altsub_Dataptr);
    R_set_altvec_Dataptr_or_null_method(altsub_class, altsub_Dataptr_or_null);
    R_set_altreal_Elt_method(altsub_class, altsub_Elt);
#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET
    R_set_altvec_Extract_array_subset_method(altsub_class,
					     altsub_Extract_array_subset);
#endif
    R_registerRoutines(dll, NULL, callMethods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
