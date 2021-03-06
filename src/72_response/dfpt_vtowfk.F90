!{\src2tex{textfont=tt}}
!!****f* ABINIT/dfpt_vtowfk
!! NAME
!! dfpt_vtowfk
!!
!! FUNCTION
!! This routine compute the partial density at a given k-point,
!! for a given spin-polarization, from a fixed potential (vlocal1).
!!
!! COPYRIGHT
!! Copyright (C) 1999-2017 ABINIT group (XG, AR, DRH, MB, MVer,XW, MT)
!! This file is distributed under the terms of the
!! GNU General Public License, see ~abinit/COPYING
!! or http://www.gnu.org/copyleft/gpl.txt .
!! For the initials of contributors, see ~abinit/doc/developers/contributors.txt .
!!
!! INPUTS
!!  cg(2,mpw*nspinor*mband*mkmem*nsppol)=planewave coefficients of wavefunctions
!!  cgq(2,mcgq)=array for planewave coefficients of wavefunctions.
!!  cg1(2,mpw1*nspinor*mband*mk1mem*nsppol)=pw coefficients of RF wavefunctions at k,q.
!!  cplex=1 if rhoaug1 is real, 2 if rhoaug1 is complex
!!  cprj(natom,nspinor*mband*mkmem*nsppol*usecprj)= wave functions at k
!!              projected with non-local projectors: cprj=<p_i|Cnk>
!!  cprjq(natom,mcprjq)= wave functions at k+q projected with non-local projectors: cprjq=<p_i|Cnk+q>
!!  dim_eig2rf = dimension for the second order eigenvalues
!!  dtfil <type(datafiles_type)>=variables related to files
!!  dtset <type(dataset_type)>=all input variables for this dataset
!!  eig0_k(nband_k)=GS eigenvalues at k (hartree)
!!  eig0_kq(nband_k)=GS eigenvalues at k+Q (hartree)
!!  fermie1=derivative of fermi energy wrt (strain) perturbation
!!  grad_berry(2,mpw1,dtefield%mband_occ) = the gradient of the Berry phase term
!!  gs_hamkq <type(gs_hamiltonian_type)>=all data for the Hamiltonian at k+q
!!  ibg=shift to be applied on the location of data in the array cprj
!!  ibgq=shift to be applied on the location of data in the array cprjq
!!  ibg1=shift to be applied on the location of data in the array cprj1
!!  icg=shift to be applied on the location of data in the array cg
!!  icgq=shift to be applied on the location of data in the array cgq
!!  icg1=shift to be applied on the location of data in the array cg1
!!  idir=direction of the current perturbation
!!  ikpt=number of the k-point
!!  ipert=type of the perturbation
!!  isppol=1 index of current spin component
!!  mband=maximum number of bands
!!  mcgq=second dimension of the cgq array
!!  mcprjq=second dimension of the cprjq array
!!  mkmem =number of k points trated by this node (GS data).
!!  mk1mem =number of k points treated by this node (RF data)
!!  mpi_enreg=information about MPI parallelization
!!  mpw=maximum dimensioned size of npw or wfs at k
!!  mpw1=maximum dimensioned size of npw for wfs at k+q (also for 1-order wfs).
!!  natom=number of atoms in cell.
!!  nband_k=number of bands at this k point for that spin polarization
!!  ncpgr=number of gradients stored in cprj array (cprj=<p_i|Cnk>)
!!  nnsclo_now=number of non-self-consistent loops for the current vtrial
!!    (often 1 for SCF calculation, =nstep for non-SCF calculations)
!!  npw_k=number of plane waves at this k point
!!  npw1_k=number of plane waves at this k+q point
!!  nspinor=number of spinorial components of the wavefunctions
!!  nsppol=1 for unpolarized, 2 for spin-polarized
!!  n4,n5,n6 used for dimensioning real space arrays
!!  occ_k(nband_k)=occupation number for each band (usually 2) for each k.
!!  prtvol=control print volume and debugging output
!!  psps <type(pseudopotential_type)>=variables related to pseudopotentials
!!  rf_hamkq <type(rf_hamiltonian_type)>=all data for the 1st-order Hamiltonian at k,q
!!  rf_hamk_dir2 <type(rf_hamiltonian_type)>= (used only when ipert=natom+11, so q=0)
!!    same as rf_hamkq, but the direction of the perturbation is different
!!  rhoaug1(cplex*n4,n5,n6,nspden)= density in electrons/bohr**3,
!!   on the augmented fft grid. (cumulative, so input as well as output)
!!  rocceig(nband_k,nband_k)= (occ_kq(m)-occ_k(n))/(eig0_kq(m)-eig0_k(n)),
!!    if this ratio has been attributed to the band n (second argument), zero otherwise
!!  ddk<wfk_t>=struct info for DDK file.
!!  wtk_k=weight assigned to the k point.
!!
!! OUTPUT
!!  cg1(2,mpw1*nspinor*mband*mk1mem*nsppol)=pw coefficients of RF
!!    wavefunctions at k,q. They are orthogonalized to the occupied states.
!!  cg1_active(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)=pw coefficients of RF
!!    wavefunctions at k,q. They are orthogonalized to the active. Only needed for ieigrf/=0
!!  edocc_k(nband_k)=correction to 2nd-order total energy coming
!!      from changes of occupation
!!  eeig0_k(nband_k)=zero-order eigenvalues contribution to 2nd-order total
!!      energy from all bands at this k point.
!!  eig1_k(2*nband_k**2)=first-order eigenvalues (hartree)
!!  ek0_k(nband_k)=0-order kinetic energy contribution to 2nd-order total
!!      energy from all bands at this k point.
!!  ek1_k(nband_k)=1st-order kinetic energy contribution to 2nd-order total
!!      energy from all bands at this k point.
!!  eloc0_k(nband_k)=zero-order local contribution to 2nd-order total energy
!!      from all bands at this k point.
!!  enl0_k(nband_k)=zero-order non-local contribution to 2nd-order total energy
!!      from all bands at this k point.
!!  enl1_k(nband_k)=first-order non-local contribution to 2nd-order total energy
!!      from all bands at this k point.
!!  gh1c_set(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)= set of <G|H^{(1)}|nK>
!!  gh0c1_set(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)= set of <G|H^{(0)}|\Psi^{(1)}>
!!      The wavefunction is orthogonal to the active space (for metals). It is not coherent with cg1.
!!  resid_k(nband_k)=residuals for each band over all k points,
!!  rhoaug1(cplex*n4,n5,n6,nspden)= density in electrons/bohr**3,
!!   on the augmented fft grid. (cumulative, so input as well as output).
!!  ==== if (gs_hamkq%usepaw==1) ====
!!    cprj1(natom,nspinor*mband*mk1mem*nsppol*usecprj)=
!!              1st-order wave functions at k,q projected with non-local projectors:
!!                       cprj1=<p_i|C1nk,q> where p_i is a non-local projector
!!    pawrhoij1(natom) <type(pawrhoij_type)>= 1st-order paw rhoij occupancies and related data
!!                                            (cumulative, so input as well as output)
!!
!! PARENTS
!!      dfpt_vtorho
!!
!! CHILDREN
!!      cg_zcopy,corrmetalwf1,dfpt_accrho,dfpt_cgwf,dotprod_g,getgsc
!!      matrixelmt_g,meanvalue_g,pawcprj_alloc,pawcprj_copy,pawcprj_free
!!      pawcprj_get,pawcprj_put,rf2_destroy,rf2_init,sqnorm_g,status,timab
!!      wfk_read_bks,wrtout
!!
!! SOURCE

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

#include "abi_common.h"

subroutine dfpt_vtowfk(cg,cgq,cg1,cg1_active,cplex,cprj,cprjq,cprj1,&
& dim_eig2rf,dtfil,dtset,&
& edocc_k,eeig0_k,eig0_k,eig0_kq,eig1_k,&
& ek0_k,ek1_k,eloc0_k,enl0_k,enl1_k,&
& fermie1,gh0c1_set,gh1c_set,grad_berry,gs_hamkq,&
& ibg,ibgq,ibg1,icg,icgq,icg1,idir,ikpt,ipert,&
& isppol,mband,mcgq,mcprjq,mkmem,mk1mem,&
& mpi_enreg,mpw,mpw1,natom,nband_k,ncpgr,&
& nnsclo_now,npw_k,npw1_k,nspinor,nsppol,&
& n4,n5,n6,occ_k,pawrhoij1,prtvol,psps,resid_k,rf_hamkq,rf_hamk_dir2,rhoaug1,rocceig,&
& ddk_f,wtk_k,nlines_done,cg1_out)

 use defs_basis
 use defs_datatypes
 use defs_abitypes
 use m_profiling_abi
 use m_errors
 use m_xmpi
 use m_cgtools
 use m_wfk
 use m_rf2

 use m_pawrhoij,     only : pawrhoij_type
 use m_pawcprj,      only : pawcprj_type, pawcprj_alloc, pawcprj_put, pawcprj_free, pawcprj_get,pawcprj_copy
 use m_hamiltonian,  only : gs_hamiltonian_type,rf_hamiltonian_type,KPRIME_H_KPRIME

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'dfpt_vtowfk'
 use interfaces_14_hidewrite
 use interfaces_18_timing
 use interfaces_32_util
 use interfaces_53_spacepar
 use interfaces_66_wfs
 use interfaces_72_response, except_this_one => dfpt_vtowfk
!End of the abilint section

 implicit none

!Arguments ------------------------------------
!scalars
 integer,intent(in) :: cplex,dim_eig2rf,ibg
 integer,intent(in) :: ibg1,ibgq,icg,icg1,icgq,idir,ikpt,ipert,isppol
 integer,intent(in) :: mband,mcgq,mcprjq,mk1mem,mkmem
 integer,intent(in) :: mpw,mpw1,n4,n5,n6,natom,ncpgr
 integer,intent(in) :: nnsclo_now,nspinor,nsppol,prtvol
 integer,optional,intent(in) :: cg1_out
 integer,intent(in) :: nband_k,npw1_k,npw_k
 integer,intent(inout) :: nlines_done
 real(dp),intent(in) :: fermie1,wtk_k
 type(MPI_type),intent(in) :: mpi_enreg
 type(datafiles_type),intent(in) :: dtfil
 type(dataset_type),intent(in) :: dtset
 type(gs_hamiltonian_type),intent(inout) :: gs_hamkq
 type(rf_hamiltonian_type),intent(inout) :: rf_hamkq,rf_hamk_dir2
 type(pseudopotential_type),intent(in) :: psps
!arrays
 real(dp),intent(in) :: cg(2,mpw*nspinor*mband*mkmem*nsppol),cgq(2,mcgq)
 real(dp),intent(in) :: eig0_k(nband_k),eig0_kq(nband_k)
 real(dp),intent(in) :: grad_berry(2,mpw1*nspinor,nband_k)
 real(dp),intent(in) :: occ_k(nband_k),rocceig(nband_k,nband_k)
 real(dp),intent(inout) :: cg1(2,mpw1*nspinor*mband*mk1mem*nsppol)
 real(dp),intent(inout) :: rhoaug1(cplex*n4,n5,n6,gs_hamkq%nvloc)
 real(dp),intent(inout) :: cg1_active(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)
 real(dp),intent(inout) :: gh1c_set(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)
 real(dp),intent(inout) :: gh0c1_set(2,mpw1*nspinor*mband*mk1mem*nsppol*dim_eig2rf)
 real(dp),intent(inout) :: edocc_k(nband_k),eeig0_k(nband_k),eig1_k(2*nband_k**2)
 real(dp),intent(out) :: ek0_k(nband_k),eloc0_k(nband_k)
 real(dp),intent(inout) :: ek1_k(nband_k)
 real(dp),intent(out) :: enl0_k(nband_k),enl1_k(nband_k)
 real(dp),intent(out) :: resid_k(nband_k)
 type(pawcprj_type),intent(in) :: cprj(natom,nspinor*mband*mkmem*nsppol*gs_hamkq%usecprj)
 type(pawcprj_type),intent(in) :: cprjq(natom,mcprjq)
 type(pawcprj_type),intent(inout) :: cprj1(natom,nspinor*mband*mk1mem*nsppol*gs_hamkq%usecprj)
 type(pawrhoij_type),intent(inout) :: pawrhoij1(natom*gs_hamkq%usepaw)
 type(wfk_t),intent(inout) :: ddk_f(4)

!Local variables-------------------------------
!scalars
 integer,parameter :: level=14,tim_fourwf=5
 integer,save :: nskip=0
 integer :: counter,iband,idir0,ierr,iexit,igs,igscq,ii,dim_dcwf,inonsc
 integer :: iorder_cprj,iorder_cprj1,ipw,iscf_mod,ispinor,me,mgscq,nkpt_max
 integer :: option,opt_gvnl1,quit,test_ddk
 integer :: tocceig,usedcwavef,ptr,shift_band
 real(dp) :: aa,ai,ar,eig0nk,resid,residk,scprod,energy_factor
 character(len=500) :: message
 type(rf2_t) :: rf2
!arrays
 real(dp) :: tsec(2)
 real(dp),allocatable :: cwave0(:,:),cwave1(:,:),cwavef(:,:)
 real(dp),allocatable :: dcwavef(:,:),gh1c_n(:,:),gh0c1(:,:)
 real(dp),allocatable :: gsc(:,:),gscq(:,:),gvnl1(:,:),gvnlc(:,:)
 real(dp),pointer :: kinpw1(:)
 type(pawcprj_type),allocatable :: cwaveprj(:,:),cwaveprj0(:,:),cwaveprj1(:,:)

! *********************************************************************

 DBG_ENTER('COLL')

!Keep track of total time spent in dfpt_vtowfk
 call timab(128,1,tsec)

 nkpt_max=50; if (xmpi_paral==1) nkpt_max=-1

 if(prtvol>2 .or. ikpt<=nkpt_max)then
   write(message,'(2a,i5,2x,a,3f9.5,2x,a)')ch10,' Non-SCF iterations; k pt #',ikpt,'k=',&
&   gs_hamkq%kpt_k(:),'band residuals:'
   call wrtout(std_out,message,'PERS')
 end if

!Initializations and allocations
 me=mpi_enreg%me_kpt
 quit=0

!The value of iscf must be modified if ddk perturbation
 iscf_mod=dtset%iscf;if(ipert==natom+1.or.ipert==natom+10.or.ipert==natom+11) iscf_mod=-3

 kinpw1 => gs_hamkq%kinpw_kp
 ABI_ALLOCATE(gh0c1,(2,npw1_k*nspinor))
 ABI_ALLOCATE(gvnlc,(2,npw1_k*nspinor))
 ABI_ALLOCATE(gvnl1,(2,npw1_k*nspinor))
 ABI_ALLOCATE(cwave0,(2,npw_k*nspinor))
 ABI_ALLOCATE(cwavef,(2,npw1_k*nspinor))
 ABI_ALLOCATE(cwave1,(2,npw1_k*nspinor))
 ABI_ALLOCATE(gh1c_n,(2,npw1_k*nspinor))
 if (gs_hamkq%usepaw==1) then
   ABI_ALLOCATE(gsc,(2,npw1_k*nspinor))
 else
   ABI_ALLOCATE(gsc,(0,0))
 end if

!Read the npw and kg records of wf files
 call status(0,dtfil%filstat,iexit,level,'before WffRead')
 test_ddk=0
 if ((ipert==natom+2.and.sum((dtset%qptn(1:3))**2)<1.0d-7.and.&
& (dtset%berryopt/= 4.and.dtset%berryopt/= 6.and.dtset%berryopt/= 7.and.&
& dtset%berryopt/=14.and.dtset%berryopt/=16.and.dtset%berryopt/=17)).or.&
& ipert==natom+10.or.ipert==natom+11) then
   test_ddk=1
   if(ipert==natom+10.or.ipert==natom+11) test_ddk=0
 end if

!Additional stuff for PAW
 ABI_DATATYPE_ALLOCATE(cwaveprj0,(0,0))
 if (gs_hamkq%usepaw==1) then
!  1-Compute all <g|S|Cnk+q>
   igscq=0
   mgscq=mpw1*nspinor*mband
   ABI_STAT_ALLOCATE(gscq,(2,mgscq), ierr)
   ABI_CHECK(ierr==0, "out of memory in gscq")

   call getgsc(cgq,cprjq,gs_hamkq,gscq,ibgq,icgq,igscq,ikpt,isppol,mcgq,mcprjq,&
&   mgscq,mpi_enreg,natom,nband_k,npw1_k,dtset%nspinor,select_k=KPRIME_H_KPRIME)
!  2-Initialize additional scalars/arrays
   iorder_cprj=0;iorder_cprj1=0
   dim_dcwf=npw1_k*nspinor;if (ipert==natom+2.or.ipert==natom+10.or.ipert==natom+11) dim_dcwf=0
   ABI_ALLOCATE(dcwavef,(2,dim_dcwf))
   if (gs_hamkq%usecprj==1) then
     ABI_DATATYPE_DEALLOCATE(cwaveprj0)
     ABI_DATATYPE_ALLOCATE(cwaveprj0,(natom,nspinor))
     call pawcprj_alloc(cwaveprj0,1,gs_hamkq%dimcprj)
   end if
   ABI_DATATYPE_ALLOCATE(cwaveprj,(natom,nspinor))
   ABI_DATATYPE_ALLOCATE(cwaveprj1,(natom,nspinor))
   call pawcprj_alloc(cwaveprj ,0,gs_hamkq%dimcprj)
   call pawcprj_alloc(cwaveprj1,0,gs_hamkq%dimcprj)
 else
   igscq=0;mgscq=0;dim_dcwf=0
   ABI_ALLOCATE(gscq,(0,0))
   ABI_ALLOCATE(dcwavef,(0,0))
   ABI_DATATYPE_ALLOCATE(cwaveprj,(0,0))
   ABI_DATATYPE_ALLOCATE(cwaveprj1,(0,0))
 end if

 energy_factor=two
 if(ipert==natom+10.or.ipert==natom+11) energy_factor=six

!For rf2 perturbation :
 if(ipert==natom+10.or.ipert==natom+11) then
   call rf2_init(cg,cprj,rf2,dtset,dtfil,eig0_k,eig1_k,gs_hamkq,ibg,icg,idir,ikpt,ipert,isppol,mkmem,&
   mpi_enreg,mpw,nband_k,nsppol,rf_hamkq,rf_hamk_dir2,occ_k,rocceig,ddk_f)
 end if

 call timab(139,1,tsec)

!======================================================================
!==================  LOOP OVER BANDS ==================================
!======================================================================

 do iband=1,nband_k

!  Skip bands not treated by current proc
   if( (mpi_enreg%proc_distrb(ikpt, iband,isppol)/=me)) cycle

!  Get ground-state wavefunctions
   ptr = 1+(iband-1)*npw_k*nspinor+icg
   call cg_zcopy(npw_k*nspinor,cg(1,ptr),cwave0)

!  Get PAW ground state projected WF (cprj)
   if (gs_hamkq%usepaw==1.and.gs_hamkq%usecprj==1.and.ipert/=natom+10.and.ipert/=natom+11) then
     idir0 = idir
     if(ipert==natom+3.or.ipert==natom+4) idir0 =1
     call pawcprj_get(gs_hamkq%atindx1,cwaveprj0,cprj,natom,iband,ibg,ikpt,iorder_cprj,&
&     isppol,mband,mkmem,natom,1,nband_k,nspinor,nsppol,dtfil%unpaw,&
&     mpicomm=mpi_enreg%comm_kpt,proc_distrb=mpi_enreg%proc_distrb,&
&     icpgr=idir0,ncpgr=ncpgr)
   end if

!  Get first-order wavefunctions
   ptr = 1+(iband-1)*npw1_k*nspinor+icg1
   call cg_zcopy(npw1_k*nspinor,cg1(1,ptr),cwavef)

!  Read PAW projected 1st-order WF (cprj)
!  Unuseful for the time being (will be recomputed in dfpt_cgwf)
!  if (gs_hamkq%usepaw==1.and.gs_hamkq%usecprj==1) then
!  call pawcprj_get(gs_hamkq%atindx1,cwaveprj,cprj1,natom,iband,ibg1,ikpt,iorder_cprj1,&
!  &    isppol,mband,mk1mem,natom,1,nband_k,nspinor,nsppol,dtfil%unpaw1,
!  &    mpicomm=mpi_enreg%comm_kpt,proc_distrb=mpi_enreg%proc_distrb)
!  end if

!  Filter the wavefunctions for large modified kinetic energy
!  The GS wavefunctions should already be non-zero
   do ispinor=1,nspinor
     igs=(ispinor-1)*npw1_k
     do ipw=1+igs,npw1_k+igs
       if(kinpw1(ipw-igs)>huge(zero)*1.d-11)then
         cwavef(1,ipw)=zero
         cwavef(2,ipw)=zero
       end if
     end do
   end do

!  If electric field, the derivative of the wf should be read, and multiplied by i.
   if(test_ddk==1) then
     ii = wfk_findk(ddk_f(1), gs_hamkq%kpt_k)
     ABI_CHECK(ii == ikpt, "ii != ikpt")
     call wfk_read_bks(ddk_f(1), iband, ikpt, isppol, xmpio_single, cg_bks=gvnl1)

!    Multiplication by -i
!    MVeithen 021212 : use + i instead,
!    See X. Gonze, Phys. Rev. B 55, 10337 (1997) Eq. (79)
!    the operator used to compute the first-order derivative
!    of the wavefunctions with respect to an electric field
!    is $+i \frac{d}{dk}$
!    This change will affect the computation of the 2dtes from non
!    stationary expressions, see dfpt_nstdy.f and dfpt_nstwf.f
     do ipw=1,npw1_k*nspinor
!      aa=gvnl1(1,ipw)
!      gvnl1(1,ipw)=gvnl1(2,ipw)
!      gvnl1(2,ipw)=-aa
       aa=gvnl1(1,ipw)
       gvnl1(1,ipw)=-gvnl1(2,ipw)
       gvnl1(2,ipw)=aa
     end do
   end if

!  Unlike in GS calculations, the inonsc loop is inside the band loop
!  nnsclo_now=number of non-self-consistent loops for the current vtrial
!  (often 1 for SCF calculation, =nstep for non-SCF calculations)
   do inonsc=1,nnsclo_now

     counter=100*iband+inonsc

!    Note that the following translation occurs in the called routine :
!    iband->band, nband_k->nband, npw_k->npw, npw1_k->npw1
     eig0nk=eig0_k(iband)
     usedcwavef=gs_hamkq%usepaw;if (dim_dcwf==0) usedcwavef=0
     if (inonsc==1) usedcwavef=2*usedcwavef
     opt_gvnl1=0;if (ipert==natom+2) opt_gvnl1=1
     if (ipert==natom+2.and.gs_hamkq%usepaw==1.and.inonsc==1) opt_gvnl1=2

     if ( (ipert/=natom+10 .and. ipert/=natom+11) .or. abs(occ_k(iband))>tol8 ) then
       call dfpt_cgwf(iband,dtset%berryopt,cgq,cwavef,cwave0,cwaveprj,cwaveprj0,rf2,dcwavef,&
&       eig0nk,eig0_kq,eig1_k,gh0c1,gh1c_n,grad_berry,gsc,gscq,gs_hamkq,gvnlc,gvnl1,icgq,&
&       idir,ipert,igscq,mcgq,mgscq,mpi_enreg,mpw1,natom,nband_k,dtset%nbdbuf,dtset%nline,&
&       npw_k,npw1_k,nspinor,opt_gvnl1,prtvol,quit,resid,rf_hamkq,dtset%dfpt_sciss,dtset%tolrde,&
&       dtset%tolwfr,usedcwavef,dtset%wfoptalg,nlines_done)
       resid_k(iband)=resid
     else
       resid_k(iband)=zero
     end if

     if (ipert/=natom+10 .and. ipert/= natom+11) then
!    At this stage, the 1st order function cwavef is orthogonal to cgq (unlike
!    when it is input to dfpt_cgwf). Here, restore the "active space" content
!    of the first-order wavefunction, to give cwave1.
!    PAW: note that dcwavef (1st-order change of WF due to overlap change)
!         remains in the subspace orthogonal to cgq
       call corrmetalwf1(cgq,cprjq,cwavef,cwave1,cwaveprj,cwaveprj1,edocc_k,eig1_k,fermie1,gh0c1,&
&       iband,ibgq,icgq,gs_hamkq%istwf_k,mcgq,mcprjq,mpi_enreg,natom,nband_k,npw1_k,nspinor,&
&       occ_k,rocceig,0,gs_hamkq%usepaw,tocceig)
     else
       tocceig=0
       call cg_zcopy(npw1_k*nspinor,cwavef,cwave1)
       if (gs_hamkq%usepaw==1) then
         call pawcprj_copy(cwaveprj,cwaveprj1)
       end if
     end if

     if (abs(occ_k(iband))<= tol8) then
       ek0_k(iband)=zero
       ek1_k(iband)=zero
       eeig0_k(iband)=zero
       enl0_k(iband)=zero
       enl1_k(iband)=zero
       eloc0_k(iband)=zero
       nskip=nskip+1
     else
!      Compute the 0-order kinetic operator contribution (with cwavef)
       call meanvalue_g(ar,kinpw1,0,gs_hamkq%istwf_k,mpi_enreg,npw1_k,nspinor,cwavef,cwavef,0)
!      There is an additional factor of 2 with respect to the bare matrix element
       ek0_k(iband)=energy_factor*ar
!      Compute the 1-order kinetic operator contribution (with cwave1 and cwave0), if needed.
!      Note that this is called only for ddk or strain, so that npw1_k=npw_k
       if(ipert==natom+1 .or. ipert==natom+3 .or. ipert==natom+4)then
         call matrixelmt_g(ai,ar,rf_hamkq%dkinpw_k,gs_hamkq%istwf_k,0,npw_k,nspinor,cwave1,cwave0,&
&         mpi_enreg%me_g0, mpi_enreg%comm_fft)
!        There is an additional factor of 4 with respect to the bare matrix element
         ek1_k(iband)=two*energy_factor*ar
       end if

!      Compute eigenvalue part of total energy (with cwavef)
       if (gs_hamkq%usepaw==1) then
         call dotprod_g(scprod,ai,gs_hamkq%istwf_k,npw1_k*nspinor,1,cwavef,gsc,mpi_enreg%me_g0,&
&         mpi_enreg%comm_spinorfft)
       else
         call sqnorm_g(scprod,gs_hamkq%istwf_k,npw1_k*nspinor,cwavef,mpi_enreg%me_g0,&
&         mpi_enreg%comm_fft)
       end if
       eeig0_k(iband)=-energy_factor*(eig0_k(iband)- (dtset%dfpt_sciss) )*scprod

!      Compute nonlocal psp contributions to nonlocal energy:
!      <G|Vnl|C1nk(perp)> is contained in gvnlc (with cwavef)
       call dotprod_g(scprod,ai,gs_hamkq%istwf_k,npw1_k*nspinor,1,cwavef,gvnlc,mpi_enreg%me_g0,&
&       mpi_enreg%comm_spinorfft)
       enl0_k(iband)=energy_factor*scprod

       if(ipert/=natom+10.and.ipert/=natom+11) then
!        <G|Vnl1|Cnk> is contained in gvnl1 (with cwave1)
         call dotprod_g(scprod,ai,gs_hamkq%istwf_k,npw1_k*nspinor,1,cwave1,gvnl1,mpi_enreg%me_g0,&
&         mpi_enreg%comm_spinorfft)
         enl1_k(iband)=two*energy_factor*scprod
       end if

!      Removal of the 1st-order kinetic energy from the 1st-order non-local part.
       if(ipert==natom+1 .or. ipert==natom+3 .or. ipert==natom+4) then
         enl1_k(iband)=enl1_k(iband)-ek1_k(iband)
       end if

!      Accumulate 1st-order density (only at the last inonsc)
!      Accumulate zero-order potential part of the 2nd-order total energy
!   BUGFIX from Max Stengel: need to initialize eloc at each inonsc iteration, in case nnonsc > 1
       eloc0_k(iband) = zero
       option=2;if (iscf_mod>0.and.inonsc==nnsclo_now) option=3
       call dfpt_accrho(counter,cplex,cwave0,cwave1,cwavef,cwaveprj0,cwaveprj1,eloc0_k(iband),&
&       dtfil%filstat,gs_hamkq,iband,idir,ipert,isppol,dtset%kptopt,mpi_enreg,natom,nband_k,ncpgr,&
&       npw_k,npw1_k,nspinor,occ_k,option,pawrhoij1,prtvol,rhoaug1,tim_fourwf,tocceig,wtk_k)
       if(ipert==natom+10.or.ipert==natom+11) eloc0_k(iband)=energy_factor*eloc0_k(iband)/two

       if(ipert==natom+10.or.ipert==natom+11) then
         shift_band=(iband-1)*npw1_k*nspinor
         call dotprod_g(scprod,ai,gs_hamkq%istwf_k,npw1_k*nspinor,1,cwave1,&
&         rf2%RHS_Stern(:,1+shift_band:npw1_k*nspinor+shift_band),mpi_enreg%me_g0, mpi_enreg%comm_spinorfft)
         ek1_k(iband)=two*energy_factor*scprod
       end if

     end if ! End of non-zero occupation

!    Exit loop over inonsc if converged and if non-self-consistent
     if (iscf_mod<0 .and. resid<dtset%tolwfr) exit

   end do ! End loop over inonsc

!  Get first-order eigenvalues and wavefunctions
   ptr = 1+(iband-1)*npw1_k*nspinor+icg1
   if (.not. present(cg1_out)) then
     call cg_zcopy(npw1_k*nspinor,cwave1,cg1(1,ptr))
   end if
   if(dim_eig2rf > 0) then
     if (.not. present(cg1_out)) then
       cg1_active(:,1+(iband-1)*npw1_k*nspinor+icg1:iband*npw1_k*nspinor+icg1)=cwavef(:,:)
     end if
     gh1c_set(:,1+(iband-1)*npw1_k*nspinor+icg1:iband*npw1_k*nspinor+icg1)=gh1c_n(:,:)
     gh0c1_set(:,1+(iband-1)*npw1_k*nspinor+icg1:iband*npw1_k*nspinor+icg1)=gh0c1(:,:)
   end if

!  PAW: write first-order projected wavefunctions
   if (psps%usepaw==1.and.gs_hamkq%usecprj==1) then
     call pawcprj_put(gs_hamkq%atindx,cwaveprj,cprj1,natom,iband,ibg1,ikpt,iorder_cprj1,isppol,&
&     mband,mk1mem,natom,1,nband_k,gs_hamkq%dimcprj,nspinor,nsppol,dtfil%unpaw1,&
&     mpicomm=mpi_enreg%comm_kpt,proc_distrb=mpi_enreg%proc_distrb,to_be_gathered=.true.)
   end if

 end do

!======================================================================
!==================  END LOOP OVER BANDS ==============================
!======================================================================

!For rf2 perturbation
 if(ipert==natom+10.or.ipert==natom+11) call rf2_destroy(rf2)

!Find largest resid over bands at this k point
 residk=maxval(resid_k(:))
 if (prtvol>2 .or. ikpt<=nkpt_max) then
   do ii=0,(nband_k-1)/8
     write(message,'(1p,8e10.2)')(resid_k(iband),iband=1+ii*8,min(nband_k,8+ii*8))
     call wrtout(std_out,message,'PERS')
   end do
 end if

 call timab(139,2,tsec)
 call timab(130,1,tsec)

 ABI_DEALLOCATE(cwave0)
 ABI_DEALLOCATE(cwavef)
 ABI_DEALLOCATE(cwave1)
 ABI_DEALLOCATE(gh0c1)
 ABI_DEALLOCATE(gvnlc)
 ABI_DEALLOCATE(gvnl1)
 ABI_DEALLOCATE(gh1c_n)

 if (gs_hamkq%usepaw==1) then
   call pawcprj_free(cwaveprj)
   call pawcprj_free(cwaveprj1)
   if (gs_hamkq%usecprj==1) then
     call pawcprj_free(cwaveprj0)
   end if
 end if
 ABI_DEALLOCATE(dcwavef)
 ABI_DEALLOCATE(gscq)
 ABI_DEALLOCATE(gsc)
 ABI_DATATYPE_DEALLOCATE(cwaveprj0)
 ABI_DATATYPE_DEALLOCATE(cwaveprj)
 ABI_DATATYPE_DEALLOCATE(cwaveprj1)

!###################################################################

!Write the number of one-way 3D ffts skipped until now (in case of fixed occupation numbers)
 if(iscf_mod>0 .and. (prtvol>2 .or. ikpt<=nkpt_max))then
   write(message,'(a,i0)')' dfpt_vtowfk : number of one-way 3D ffts skipped in vtowfk3 until now =',nskip
   call wrtout(std_out,message,'PERS')
 end if

 if(prtvol<=2 .and. ikpt==nkpt_max+1)then
   write(message,'(3a)') ch10,' dfpt_vtowfk : prtvol=0, 1 or 2, do not print more k-points.',ch10
   call wrtout(std_out,message,'PERS')
 end if

 if (residk>dtset%tolwfr .and. iscf_mod<=0 .and. iscf_mod/=-3) then
   write(message,'(a,2i0,a,es13.5)')'Wavefunctions not converged for nnsclo,ikpt=',nnsclo_now,&
&   ikpt,' max resid=',residk
   MSG_WARNING(message)
 end if

 call timab(130,2,tsec)
 call timab(128,2,tsec)

 DBG_EXIT('COLL')

end subroutine dfpt_vtowfk
!!***
